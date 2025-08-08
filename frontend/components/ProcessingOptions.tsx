'use client';

interface ProcessingOptionsProps {
  selectedFilter: string;
  onChange: (filter: string) => void;
}

export default function ProcessingOptions({ selectedFilter, onChange }: ProcessingOptionsProps) {
  const filters = [
    { id: 'grayscale', name: 'Grayscale', description: 'Convert to black and white' },
    { id: 'blur', name: 'Blur', description: 'Apply gaussian blur' },
    { id: 'sharpen', name: 'Sharpen', description: 'Enhance edge contrast' },
    { id: 'sepia', name: 'Sepia', description: 'Vintage brown tone' },
  ];

  return (
    <div className="grid grid-cols-2 gap-4">
      {filters.map((filter) => (
        <button
          key={filter.id}
          onClick={() => onChange(filter.id)}
          className={`p-4 rounded-lg border-2 transition-all text-left ${
            selectedFilter === filter.id
              ? 'border-stone-900 bg-stone-100'
              : 'border-stone-200 hover:border-stone-400 bg-white'
          }`}
        >
          <div className="font-medium text-stone-900">{filter.name}</div>
          <div className="text-sm text-stone-500 mt-1">{filter.description}</div>
        </button>
      ))}
    </div>
  );
}