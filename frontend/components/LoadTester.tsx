'use client';

import { useState } from 'react';
import { Zap, PlayCircle, StopCircle } from 'lucide-react';

export default function LoadTester() {
  const [isRunning, setIsRunning] = useState(false);
  const [config, setConfig] = useState({
    intensity: 'medium',
    duration: 10,
    threads: 4
  });
  const [status, setStatus] = useState<string>('');

  const startLoadTest = async () => {
    setIsRunning(true);
    setStatus('Starting CPU load test...');

    try {
      const response = await fetch(
        '/api/load-test',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            intensity: config.intensity,
            duration: config.duration,
            threads: config.threads
          })
        }
      );

      if (response.ok) {
        setStatus(`Load test running for ${config.duration} seconds...`);
        
        // Wait for the test duration then update status
        setTimeout(() => {
          setStatus('Load test completed');
          setIsRunning(false);
        }, config.duration * 1000);
      } else {
        setStatus('Failed to start load test');
        setIsRunning(false);
      }
    } catch (error) {
      console.error('Load test error:', error);
      setStatus('Error starting load test');
      setIsRunning(false);
    }
  };

  const stopLoadTest = async () => {
    try {
      await fetch(
        '/api/load-test/stop',
        { method: 'POST' }
      );
      setStatus('Load test stopped');
      setIsRunning(false);
    } catch (error) {
      console.error('Error stopping load test:', error);
    }
  };

  return (
    <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
      <h2 className="text-2xl font-light mb-6 text-stone-800 flex items-center gap-2">
        <Zap className="h-6 w-6 text-stone-600" />
        CPU Load Tester
      </h2>

      <div className="space-y-4">
        <div>
          <label className="block text-sm text-stone-600 mb-2">Intensity</label>
          <select
            value={config.intensity}
            onChange={(e) => setConfig({ ...config, intensity: e.target.value })}
            disabled={isRunning}
            className="w-full px-4 py-2 bg-white border border-stone-300 text-stone-900 rounded-lg focus:ring-2 focus:ring-stone-500 focus:border-transparent disabled:opacity-50"
          >
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
            <option value="extreme">Extreme</option>
          </select>
        </div>

        <div>
          <label className="block text-sm text-stone-600 mb-2">Duration (seconds)</label>
          <input
            type="number"
            min="5"
            max="60"
            value={config.duration}
            onChange={(e) => setConfig({ ...config, duration: parseInt(e.target.value) || 10 })}
            disabled={isRunning}
            className="w-full px-4 py-2 bg-white border border-stone-300 text-stone-900 rounded-lg focus:ring-2 focus:ring-stone-500 focus:border-transparent disabled:opacity-50"
          />
        </div>

        <div>
          <label className="block text-sm text-stone-600 mb-2">Thread Count</label>
          <input
            type="number"
            min="1"
            max="16"
            value={config.threads}
            onChange={(e) => setConfig({ ...config, threads: parseInt(e.target.value) || 4 })}
            disabled={isRunning}
            className="w-full px-4 py-2 bg-white border border-stone-300 text-stone-900 rounded-lg focus:ring-2 focus:ring-stone-500 focus:border-transparent disabled:opacity-50"
          />
        </div>

        <button
          onClick={isRunning ? stopLoadTest : startLoadTest}
          className={`w-full py-3 px-4 rounded-lg font-medium transition-all flex items-center justify-center gap-2 ${
            isRunning
              ? 'bg-red-600 hover:bg-red-700 text-white'
              : 'bg-stone-900 hover:bg-stone-800 text-white'
          }`}
        >
          {isRunning ? (
            <>
              <StopCircle className="h-5 w-5" />
              Stop Load Test
            </>
          ) : (
            <>
              <PlayCircle className="h-5 w-5" />
              Start Load Test
            </>
          )}
        </button>

        {status && (
          <div className="mt-4 p-4 bg-stone-50 rounded-lg border border-stone-200">
            <p className="text-sm text-stone-700">{status}</p>
          </div>
        )}
      </div>
    </div>
  );
}