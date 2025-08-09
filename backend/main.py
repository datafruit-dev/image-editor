from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from pydantic import BaseModel
from fastapi.responses import JSONResponse
import base64
import io
import time
from typing import List, Optional
from PIL import Image, ImageFilter, ImageEnhance, ImageOps
import numpy as np
from datetime import datetime
import asyncio
import uvicorn
import psutil
import threading
import random

app = FastAPI(title="Image Processing Service")

class MetricsTracker:
    def __init__(self):
        self.total_processed = 0
        self.active_connections = 0
        self.queue_size = 0
        self.errors = 0
        self.response_times = []
        self.last_request_time = time.time()
    
    def add_response_time(self, duration):
        self.response_times.append(duration)
        if len(self.response_times) > 100:
            self.response_times.pop(0)
    
    def get_avg_response_time(self):
        if not self.response_times:
            return 0
        return int(sum(self.response_times) / len(self.response_times))
    
    def get_requests_per_second(self):
        time_diff = time.time() - self.last_request_time
        if time_diff > 0:
            return round(1 / time_diff, 2)
        return 0

metrics = MetricsTracker()

# Global flag for CPU load simulation
cpu_load_active = False

def cpu_intensive_task(duration_seconds: float, intensity: str = "medium"):
    """Run CPU-intensive operations in background"""
    end_time = time.time() + duration_seconds
    
    # Different intensity levels - reduced to prevent blocking
    iterations = {
        "low": 1000,
        "medium": 5000,
        "high": 10000,
        "extreme": 20000
    }.get(intensity, 5000)
    
    while time.time() < end_time and cpu_load_active:
        # Random mathematical operations
        result = 0
        for i in range(iterations):
            result += random.random() * np.sin(i) * np.cos(i)
            if i % 100 == 0:
                # Create and destroy smaller arrays
                arr = np.random.rand(10, 10)
                _ = np.sum(arr)
        
        # Larger sleep to allow other operations
        time.sleep(0.1)

def apply_grayscale(image: Image.Image) -> Image.Image:
    """Convert image to grayscale"""
    # Convert to RGB first if needed
    if image.mode != 'RGB':
        image = image.convert('RGB')
    return ImageOps.grayscale(image)

def apply_blur(image: Image.Image) -> Image.Image:
    """Apply Gaussian blur to image"""
    image = image.filter(ImageFilter.GaussianBlur(radius=5))
    return image

def apply_sharpen(image: Image.Image) -> Image.Image:
    """Apply sharpening filter to image"""
    sharpened = image.filter(ImageFilter.SHARPEN)
    return sharpened

def apply_sepia(image: Image.Image) -> Image.Image:
    """Apply sepia tone effect to image"""
    # Convert to RGB if needed
    if image.mode != 'RGB':
        image = image.convert('RGB')
    
    # Get image data as numpy array
    pixels = np.array(image)
    
    # Sepia transformation matrix
    sepia_filter = np.array([
        [0.393, 0.769, 0.189],
        [0.349, 0.686, 0.168],
        [0.272, 0.534, 0.131]
    ])
    
    # Apply the sepia filter
    sepia_pixels = pixels @ sepia_filter.T
    sepia_pixels = np.clip(sepia_pixels, 0, 255).astype(np.uint8)
    
    # Add some CPU-intensive processing
    # for _ in range(2):
    #     # Simulate complex calculations
    #     temp = np.sqrt(np.square(sepia_pixels.astype(np.float64)) + 1)
    #     sepia_pixels = np.clip(temp, 0, 255).astype(np.uint8)
    
    return Image.fromarray(sepia_pixels)

def image_to_base64(image: Image.Image, format: str = "JPEG") -> str:
    """Convert PIL Image to base64 string"""
    buffered = io.BytesIO()
    
    # Convert RGBA to RGB if saving as JPEG
    if format.upper() == "JPEG" and image.mode == "RGBA":
        # Create a white background
        rgb_image = Image.new("RGB", image.size, (255, 255, 255))
        rgb_image.paste(image, mask=image.split()[3] if len(image.split()) == 4 else None)
        image = rgb_image
    elif format.upper() == "JPEG" and image.mode not in ["RGB", "L"]:
        # Convert any other non-compatible mode to RGB
        image = image.convert("RGB")
    
    image.save(buffered, format=format)
    img_str = base64.b64encode(buffered.getvalue()).decode()
    return f"data:image/{format.lower()};base64,{img_str}"

def process_image_with_filter(image: Image.Image, filter_type: str) -> Image.Image:
    """Apply the specified filter to an image"""
    global cpu_load_active
    
    filter_map = {
        'grayscale': apply_grayscale,
        'blur': apply_blur,
        'sharpen': apply_sharpen,
        'sepia': apply_sepia
    }
    
    filter_func = filter_map.get(filter_type, apply_grayscale)
    
    # Start background CPU load based on filter type
    cpu_load_active = True
    
    # Run CPU intensive task for 5 seconds for all filters
    # Different intensities for different filters
    duration = 5  # 5 seconds
    
    if filter_type == 'blur':
        # Start 4 background threads with medium intensity for 5 seconds
        for _ in range(4):
            thread = threading.Thread(target=cpu_intensive_task, args=(duration, "medium"))
            thread.daemon = True
            thread.start()
    elif filter_type == 'sharpen':
        # Start 6 background threads with high intensity for 5 seconds
        for _ in range(6):
            thread = threading.Thread(target=cpu_intensive_task, args=(duration, "high"))
            thread.daemon = True
            thread.start()
    elif filter_type == 'sepia':
        # Start 8 background threads with extreme intensity for 5 seconds
        for _ in range(8):
            thread = threading.Thread(target=cpu_intensive_task, args=(duration, "extreme"))
            thread.daemon = True
            thread.start()
    else:  # grayscale
        # Start 2 background threads with low intensity for 5 seconds
        for _ in range(2):
            thread = threading.Thread(target=cpu_intensive_task, args=(duration, "low"))
            thread.daemon = True
            thread.start()
    
    # Apply the actual filter
    result = filter_func(image)
    
    # Let the CPU load run for a bit
    time.sleep(0.5)
    
    return result

@app.post("/api/process")
async def process_images(
    images: List[UploadFile] = File(...),
    filter: str = Form('grayscale')
):
    """Process uploaded images with the specified filter"""
    print(f"Received request with filter: {filter}")
    print(f"Number of images: {len(images)}")
    
    metrics.active_connections += 1
    metrics.queue_size = max(0, metrics.active_connections - 1)
    start_time = time.time()
    
    try:
        results = []
        
        for idx, image_file in enumerate(images):
            print(f"Processing image {idx + 1}/{len(images)}")
            # Read the uploaded image
            image_data = await image_file.read()
            print(f"Read {len(image_data)} bytes")
            
            image = Image.open(io.BytesIO(image_data))
            print(f"Image opened: {image.size}, mode: {image.mode}")
            
            # Store original as base64
            original_base64 = image_to_base64(image)
            print(f"Original base64 created")
            
            # Process the image
            process_start = time.time()
            processed_image = process_image_with_filter(image, filter)
            print(f"Image processed with filter: {filter}")
            process_duration = int((time.time() - process_start) * 1000)
            
            # Convert processed image to base64
            if processed_image.mode == 'L':  # Grayscale
                processed_image = processed_image.convert('RGB')
            processed_base64 = image_to_base64(processed_image)
            
            results.append({
                'original': original_base64,
                'processed': processed_base64,
                'processingTime': process_duration
            })
            
            metrics.total_processed += 1
        
        # Update metrics
        total_duration = int((time.time() - start_time) * 1000)
        metrics.add_response_time(total_duration)
        metrics.last_request_time = time.time()
        
        return JSONResponse(content={'results': results})
    
    except Exception as e:
        metrics.errors += 1
        print(f"Error processing image: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        metrics.active_connections -= 1
        metrics.queue_size = max(0, metrics.active_connections - 1)
        # Note: CPU load will continue running in background for 5 seconds

@app.get("/api/metrics")
async def get_metrics():
    """Get current service metrics"""
    # Get CPU usage percentage with no blocking interval
    cpu_percent = psutil.cpu_percent(interval=None)
    
    # Get memory usage
    memory = psutil.virtual_memory()
    
    return JSONResponse(content={
        'cpu': cpu_percent,
        'memory': memory.percent,
        'requestsPerSecond': metrics.get_requests_per_second(),
        'avgResponseTime': metrics.get_avg_response_time(),
        'queueSize': metrics.queue_size,
        'activeConnections': metrics.active_connections,
        'totalProcessed': metrics.total_processed,
        'errors': metrics.errors
    })

class LoadTestRequest(BaseModel):
    intensity: str = "medium"
    duration: int = 10
    threads: int = 4

@app.post("/api/load-test")
async def start_load_test(request: LoadTestRequest):
    """Start a CPU load test with configurable parameters"""
    global cpu_load_active
    cpu_load_active = True
    
    # Start the specified number of threads
    for _ in range(request.threads):
        thread = threading.Thread(
            target=cpu_intensive_task, 
            args=(request.duration, request.intensity)
        )
        thread.daemon = True
        thread.start()
    
    return JSONResponse(content={
        "status": "started",
        "intensity": request.intensity,
        "duration": request.duration,
        "threads": request.threads
    })

@app.post("/api/load-test/stop")
async def stop_load_test():
    """Stop all running CPU load tests"""
    global cpu_load_active
    cpu_load_active = False
    
    return JSONResponse(content={"status": "stopped"})

@app.get("/api/health")
async def health_check():
    """Health check endpoint for Kubernetes"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Image Processing API",
        "version": "1.0.0",
        "endpoints": [
            "/api/process",
            "/api/metrics",
            "/api/health"
        ]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)