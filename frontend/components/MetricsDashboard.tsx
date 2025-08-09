'use client';

import { useEffect, useState } from 'react';
import { Activity, Clock, TrendingUp, AlertCircle } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

interface Metrics {
  cpu: number;
  memory: number;
  requestsPerSecond: number;
  avgResponseTime: number;
  queueSize: number;
  activeConnections: number;
  totalProcessed: number;
  errors: number;
}

export default function MetricsDashboard() {
  const [metrics, setMetrics] = useState<Metrics>({
    cpu: 0,
    memory: 0,
    requestsPerSecond: 0,
    avgResponseTime: 0,
    queueSize: 0,
    activeConnections: 0,
    totalProcessed: 0,
    errors: 0
  });

  const [cpuHistory, setCpuHistory] = useState<any[]>([]);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        const response = await fetch('/api/metrics');
        if (response.ok) {
          const data = await response.json();
          setMetrics(data);
          setIsConnected(true);
          
          setCpuHistory(prev => {
            const newHistory = [...prev, { time: new Date().toLocaleTimeString(), value: data.cpu }];
            return newHistory.slice(-20);
          });
        }
      } catch (error) {
        // Silently handle connection errors - backend might not be running
        setIsConnected(false);
      }
    };

    fetchMetrics();
    const interval = setInterval(fetchMetrics, 2000);
    return () => clearInterval(interval);
  }, []);

  if (!isConnected) {
    return (
      <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
        <div className="text-center text-stone-500">
          <Activity className="h-8 w-8 mx-auto mb-2 text-stone-400" />
          <p className="text-sm">Waiting for backend service...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-2xl p-8 shadow-sm border border-stone-200">
      <div className="mb-6">
        <div className="bg-stone-50 rounded-lg p-4 border border-stone-200 mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-stone-600">CPU Usage</span>
            <Activity className="h-4 w-4 text-stone-400" />
          </div>
          <div className="text-3xl font-light text-stone-900">
            {metrics.cpu.toFixed(1)}%
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-stone-50 rounded-lg p-4 border border-stone-200">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-stone-600">Queue</span>
              <Clock className="h-4 w-4 text-stone-400" />
            </div>
            <div className="text-2xl font-light text-stone-900">
              {metrics.queueSize}
            </div>
          </div>
          
          <div className="bg-stone-50 rounded-lg p-4 border border-stone-200">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-stone-600">Response</span>
              <TrendingUp className="h-4 w-4 text-stone-400" />
            </div>
            <div className="text-2xl font-light text-stone-900">
              {metrics.avgResponseTime}ms
            </div>
          </div>
        </div>
      </div>

      {cpuHistory.length > 1 && (
        <div>
          <h3 className="text-sm text-stone-600 mb-2">CPU Usage %</h3>
          <div className="h-32">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={cpuHistory}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e5e5" />
                <XAxis dataKey="time" hide />
                <YAxis domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#fafaf9', border: '1px solid #e5e5e5' }}
                  labelStyle={{ color: '#57534e' }}
                  formatter={(value: number) => `${value.toFixed(1)}%`}
                />
                <Line 
                  type="monotone" 
                  dataKey="value" 
                  stroke="#292524" 
                  strokeWidth={2} 
                  dot={false}
                  isAnimationActive={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      <div className="mt-4 pt-4 border-t border-stone-200">
        <div className="grid grid-cols-3 gap-4 text-sm">
          <div>
            <span className="text-stone-500">Processed</span>
            <p className="font-medium text-stone-900">{metrics.totalProcessed}</p>
          </div>
          <div>
            <span className="text-stone-500">Active</span>
            <p className="font-medium text-stone-900">{metrics.activeConnections}</p>
          </div>
          <div>
            <span className="text-stone-500">Errors</span>
            <p className="font-medium text-red-600 flex items-center gap-1">
              {metrics.errors > 0 && <AlertCircle className="h-3 w-3" />}
              {metrics.errors}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}