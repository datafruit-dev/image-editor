import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://backend.internal.local:8080';

export async function POST(request: NextRequest) {
  try {
    const response = await fetch(`${BACKEND_URL}/api/load-test/stop`, {
      method: 'POST',
    });

    if (!response.ok) {
      throw new Error(`Backend responded with status: ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error stopping load test:', error);
    return NextResponse.json(
      { error: 'Failed to stop load test' },
      { status: 500 }
    );
  }
}