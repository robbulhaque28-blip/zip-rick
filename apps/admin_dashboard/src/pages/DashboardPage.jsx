import React, { useState, useEffect } from 'react';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    total_customers: 0, total_drivers: 0, pending_drivers: 0,
    active_rides: 0, today_rides: 0, revenue: { total: 0, today: 0 }
  });
  const [error, setError] = useState('');

  const loadData = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) {
        setError('Not logged in');
        return;
      }
      const res = await fetch(API + '/admin/dashboard', {
        headers: { Authorization: 'Bearer ' + token }
      });
      
      // If 401, token is expired - redirect to login
      if (res.status === 401) {
        localStorage.removeItem('admin_token');
        window.location.href = '/login';
        return;
      }
      
      const data = await res.json();
      if (data.success && data.data && data.data.overview) {
        setStats(data.data.overview);
        setError('');
      } else {
        setError('Failed to load data');
      }
    } catch (e) {
      setError('Network error');
    }
  };

  useEffect(() => { loadData(); }, []);

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif', maxWidth: 1200 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h1 style={{ margin: 0, fontSize: 24 }}>Zip-Rick Dashboard</h1>
      </div>
      
      {error && <p style={{ color: 'red', marginBottom: 12 }}>{error}</p>}
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 20 }}>
        <Card title="Total Customers" value={stats.total_customers || 0} color="#6C63FF" />
        <Card title="Total Drivers" value={stats.total_drivers || 0} color="#00D9A6" />
        <Card title="Active Rides" value={stats.active_rides || 0} color="#FFA726" />
        <Card title="Revenue" value={"\u20B9" + ((stats.revenue?.total || 0)).toLocaleString()} color="#66BB6A" />
      </div>
      
      <div style={{ background: 'white', borderRadius: 10, padding: 16, boxShadow: '0 1px 4px rgba(0,0,0,0.1)' }}>
        <h4 style={{ margin: '0 0 12px 0', fontSize: 14, color: '#666' }}>Revenue Overview</h4>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 80 }}>
          {chartData.map((d, i) => (
            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ width: '100%', background: '#6C63FF', height: Math.round(d.revenue / 120), borderRadius: '3px 3px 0 0' }}></div>
              <span style={{ fontSize: 9, marginTop: 2, color: '#999' }}>{d.day}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const chartData = [
  { day: 'Mon', revenue: 4500, rides: 45 },
  { day: 'Tue', revenue: 5200, rides: 52 },
  { day: 'Wed', revenue: 4800, rides: 48 },
  { day: 'Thu', revenue: 6100, rides: 61 },
  { day: 'Fri', revenue: 7200, rides: 72 },
  { day: 'Sat', revenue: 8900, rides: 89 },
  { day: 'Sun', revenue: 5600, rides: 56 },
];

function Card({ title, value, color }) {
  return (
    <div style={{ padding: 20, borderRadius: 10, boxShadow: '0 1px 4px rgba(0,0,0,0.1)', background: 'white' }}>
      <p style={{ color: '#666', margin: '0 0 6px 0', fontSize: 13 }}>{title}</p>
      <h2 style={{ margin: 0, color: color, fontSize: 28 }}>{value}</h2>
    </div>
  );
}