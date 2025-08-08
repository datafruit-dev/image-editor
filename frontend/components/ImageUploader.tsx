'use client';

import { useState, useCallback } from 'react';
import { Upload, X, Image as ImageIcon } from 'lucide-react';

interface ImageUploaderProps {
  onUpload: (files: File[]) => void;
}

export default function ImageUploader({ onUpload }: ImageUploaderProps) {
  const [dragActive, setDragActive] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFiles(e.dataTransfer.files);
    }
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      handleFiles(e.target.files);
    }
  };

  const handleFiles = (fileList: FileList) => {
    const newFiles = Array.from(fileList).filter(file => 
      file.type.startsWith('image/')
    );
    
    const newPreviews = newFiles.map(file => URL.createObjectURL(file));
    
    setFiles(prev => [...prev, ...newFiles]);
    setPreviews(prev => [...prev, ...newPreviews]);
    onUpload([...files, ...newFiles]);
  };

  const removeFile = (index: number) => {
    const newFiles = files.filter((_, i) => i !== index);
    const newPreviews = previews.filter((_, i) => i !== index);
    
    URL.revokeObjectURL(previews[index]);
    
    setFiles(newFiles);
    setPreviews(newPreviews);
    onUpload(newFiles);
  };

  const clearAll = () => {
    previews.forEach(preview => URL.revokeObjectURL(preview));
    setFiles([]);
    setPreviews([]);
    onUpload([]);
  };

  return (
    <div className="space-y-4">
      <div
        className={`relative border-2 border-dashed rounded-xl p-8 text-center transition-all ${
          dragActive ? 'border-stone-900 bg-stone-100' : 'border-stone-300 hover:border-stone-400 bg-white'
        }`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          type="file"
          multiple
          accept="image/*"
          onChange={handleChange}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
        />
        
        <Upload className="mx-auto h-12 w-12 text-stone-400 mb-4" />
        <p className="text-lg mb-2 text-stone-700">
          Drag and drop images here, or click to select
        </p>
        <p className="text-sm text-stone-500">
          Supports JPG, PNG, GIF, WebP
        </p>
      </div>

      {files.length > 0 && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <p className="text-sm text-stone-600">
              {files.length} image{files.length !== 1 ? 's' : ''} selected
            </p>
            <button
              onClick={clearAll}
              className="text-sm text-red-600 hover:text-red-700 transition-colors font-medium"
            >
              Clear all
            </button>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {previews.map((preview, index) => (
              <div key={index} className="relative group">
                <img
                  src={preview}
                  alt={`Preview ${index + 1}`}
                  className="w-full h-32 object-cover rounded-lg border border-stone-200"
                />
                <button
                  onClick={() => removeFile(index)}
                  className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <X className="h-4 w-4 text-stone-600" />
                </button>
                <div className="absolute bottom-2 left-2 right-2 bg-white/90 rounded px-2 py-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <p className="text-xs text-stone-700 truncate">
                    {files[index].name}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}