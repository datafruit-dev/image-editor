'use client';

import { useState } from 'react';
import ImageUploader from '@/components/ImageUploader';
import ProcessingOptions from '@/components/ProcessingOptions';
import MetricsDashboard from '@/components/MetricsDashboard';
import ProcessedResults from '@/components/ProcessedResults';
import LoadTester from '@/components/LoadTester';
import AsciiHeader from '@/components/AsciiHeader';

export default function Home() {
  const [uploadedImages, setUploadedImages] = useState<File[]>([]);
  const [processedImages, setProcessedImages] = useState<any[]>([]);
  const [processing, setProcessing] = useState(false);
  const [selectedFilter, setSelectedFilter] = useState('grayscale');

  const handleImageUpload = (files: File[]) => {
    setUploadedImages(files);
  };

  const handleProcess = async () => {
    setProcessing(true);
    
    const formData = new FormData();
    uploadedImages.forEach((file) => {
      formData.append(`images`, file);
    });
    
    formData.append('filter', selectedFilter);
    
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080'}/api/process`, {
        method: 'POST',
        body: formData
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      if (data.results) {
        setProcessedImages(data.results);
      } else {
        console.error('No results in response:', data);
        setProcessedImages([]);
      }
    } catch (error) {
      console.error('Processing error:', error);
      setProcessedImages([]);
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="min-h-screen bg-stone-50">
      <div className="container mx-auto px-6 py-12">
        <AsciiHeader />

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
          <div className="lg:col-span-2 space-y-8">
            <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
              <h2 className="text-2xl font-light mb-6 text-stone-800">Upload Images</h2>
              <ImageUploader onUpload={handleImageUpload} />
            </div>

            <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
              <h2 className="text-2xl font-light mb-6 text-stone-800">Select Filter</h2>
              <ProcessingOptions 
                selectedFilter={selectedFilter} 
                onChange={setSelectedFilter}
              />
            </div>

            <button
              onClick={handleProcess}
              disabled={uploadedImages.length === 0 || processing}
              className="w-full bg-stone-900 hover:bg-stone-800 disabled:bg-stone-300 text-white font-medium py-4 px-8 rounded-xl transition-all duration-200 shadow-sm"
            >
              {processing ? 'Processing...' : 'Process Images'}
            </button>
          </div>

          <div className="space-y-8">
            <MetricsDashboard />
            <LoadTester />
          </div>
        </div>

        {processedImages && processedImages.length > 0 && (
          <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
            <h2 className="text-2xl font-light mb-6 text-stone-800">Results</h2>
            <ProcessedResults images={processedImages} />
          </div>
        )}
      </div>
    </div>
  );
}