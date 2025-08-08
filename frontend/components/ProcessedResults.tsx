'use client';

import { useState } from 'react';
import { Download, Maximize2, X } from 'lucide-react';

interface ProcessedResultsProps {
  images: any[];
}

export default function ProcessedResults({ images }: ProcessedResultsProps) {
  const [selectedImage, setSelectedImage] = useState<any>(null);

  const downloadImage = (imageData: string, filename: string) => {
    const link = document.createElement('a');
    link.href = imageData;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const downloadAll = () => {
    images.forEach((image, index) => {
      setTimeout(() => {
        downloadImage(image.processed, `processed-${index + 1}.jpg`);
      }, index * 100);
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <p className="text-sm text-stone-600">
          {images.length} image{images.length !== 1 ? 's' : ''} processed
        </p>
        <button
          onClick={downloadAll}
          className="flex items-center gap-2 px-4 py-2 bg-stone-900 hover:bg-stone-800 text-white rounded-lg transition-colors"
        >
          <Download className="h-4 w-4" />
          Download All
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {images.map((image, index) => (
          <div key={index} className="space-y-2">
            <h3 className="text-sm font-medium text-stone-600">Image {index + 1}</h3>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <p className="text-xs text-stone-500 mb-1">Original</p>
                <div className="relative group">
                  <img
                    src={image.original}
                    alt={`Original ${index + 1}`}
                    className="w-full h-40 object-cover rounded-lg border border-stone-200 cursor-pointer"
                    onClick={() => setSelectedImage({ ...image, type: 'original', index })}
                  />
                  <button
                    onClick={() => setSelectedImage({ ...image, type: 'original', index })}
                    className="absolute top-2 right-2 p-1 bg-white/90 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-md"
                  >
                    <Maximize2 className="h-4 w-4 text-stone-700" />
                  </button>
                </div>
              </div>
              <div>
                <p className="text-xs text-stone-500 mb-1">Processed</p>
                <div className="relative group">
                  <img
                    src={image.processed}
                    alt={`Processed ${index + 1}`}
                    className="w-full h-40 object-cover rounded-lg border border-stone-200 cursor-pointer"
                    onClick={() => setSelectedImage({ ...image, type: 'processed', index })}
                  />
                  <button
                    onClick={() => setSelectedImage({ ...image, type: 'processed', index })}
                    className="absolute top-2 right-2 p-1 bg-white/90 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-md"
                  >
                    <Maximize2 className="h-4 w-4 text-stone-700" />
                  </button>
                  <button
                    onClick={() => downloadImage(image.processed, `processed-${index + 1}.jpg`)}
                    className="absolute bottom-2 right-2 p-1 bg-stone-900 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    <Download className="h-4 w-4 text-white" />
                  </button>
                </div>
              </div>
            </div>
            {image.processingTime && (
              <div className="flex justify-between text-xs text-stone-500">
                <span>Processing time:</span>
                <span className="text-stone-700 font-medium">{image.processingTime}ms</span>
              </div>
            )}
          </div>
        ))}
      </div>

      {selectedImage && (
        <div 
          className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4"
          onClick={() => setSelectedImage(null)}
        >
          <div className="relative max-w-6xl max-h-full">
            <button
              onClick={() => setSelectedImage(null)}
              className="absolute -top-12 right-0 p-2 text-white hover:text-stone-300 transition-colors"
            >
              <X className="h-6 w-6" />
            </button>
            <img
              src={selectedImage.type === 'original' ? selectedImage.original : selectedImage.processed}
              alt={`${selectedImage.type} ${selectedImage.index + 1}`}
              className="max-w-full max-h-[80vh] object-contain rounded-lg"
              onClick={(e) => e.stopPropagation()}
            />
            <div className="absolute bottom-4 left-4 bg-white/90 rounded-lg px-4 py-2">
              <p className="text-stone-900 text-sm font-medium">
                {selectedImage.type === 'original' ? 'Original' : 'Processed'} Image {selectedImage.index + 1}
              </p>
            </div>
            {selectedImage.type === 'processed' && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  downloadImage(selectedImage.processed, `processed-${selectedImage.index + 1}.jpg`);
                }}
                className="absolute bottom-4 right-4 flex items-center gap-2 px-4 py-2 bg-stone-900 hover:bg-stone-800 text-white rounded-lg transition-colors"
              >
                <Download className="h-4 w-4" />
                Download
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}