# Image Processing Backend

## Setup

1. Create a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the server:
```bash
python main.py
```

The backend will start on http://localhost:8080

## API Endpoints

- `POST /api/process` - Process images with filters
  - Accepts: multipart/form-data with image files and filter type
  - Filters: grayscale, blur, sharpen, sepia
  
- `GET /api/metrics` - Get service metrics
  - Returns: JSON with performance metrics
  
- `GET /api/health` - Health check endpoint
  - Returns: Service health status

## Docker Support

Build and run with Docker:
```bash
docker build -t image-processor-backend .
docker run -p 8080:8080 image-processor-backend
```