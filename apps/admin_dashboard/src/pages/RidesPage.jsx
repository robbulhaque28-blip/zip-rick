import React, { useState, useEffect } from 'react';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function RidesPage() {
  const [rides, setRides] = useState([]);
  const [tab, setTab] = useState('all');

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        let url = API + '/admin/rides?limit=50';
        if (tab === 'active') url = API + '/admin/rides/active';
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
        const data = await res.json();
        if (data.success) {
          if (tab === 'active' && data.data?.rides) setRides(data.data.rides);
          else if (Array.isArray(data.data)) setRides(data.data);
        }
      } catch (e) {}
    };
    load();
  }, [tab]);

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>Ride Management</h1>
      <div style={{ marginBottom: 16 }}>
        <button onClick={() => setTab('all')} style={{ padding: '8px 16px', marginRight: 8, background: tab === 'all' ? '#6C63FF' : '#e0e0e0', color: tab === 'all' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>All Rides</button>
        <button onClick={() => setTab('active')} style={{ padding: '8px 16px', background: tab === 'active' ? '#6C63FF' : '#e0e0e0', color: tab === 'active' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>Active Rides</button>
      </div>
      <p style={{ color: '#666', marginBottom: 12 }}>{rides.length} ride(s)</p>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white', borderRadius: 8, overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
        <thead>
          <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
            <th style={{ padding: 12 }}>Ride #</th>
            <th style={{ padding: 12 }}>Customer</th>
            <th style={{ padding: 12 }}>Driver</th>
            <th style={{ padding: 12 }}>Pickup</th>
            <th style={{ padding: 12 }}>Drop</th>
            <th style={{ padding: 12 }}>Fare</th>
            <th style={{ padding: 12 }}>Status</th>
          </tr>
        </thead>
        <tbody>
          {rides.length === 0 && <tr><td colSpan="7" style={{ padding: 24, textAlign: 'center', color: '#999' }}>No rides found</td></tr>}
          {rides.map(r => (
            <tr key={r.id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={{ padding: 12 }}>{r.ride_number || 'N/A'}</td>
              <td style={{ padding: 12 }}>{r.customer?.user?.full_name || 'N/A'}</td>
              <td style={{ padding: 12 }}>{r.driver?.user?.full_name || 'Not assigned'}</td>
              <td style={{ padding: 12, maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.pickup_address || 'N/A'}</td>
              <td style={{ padding: 12, maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.drop_address || 'N/A'}</td>
              <td style={{ padding: 12 }}>Rs {r.total_fare || 0}</td>
              <td style={{ padding: 12 }}><span style={{ padding: '2px 8px', borderRadius: 4, background: r.status === 'completed' ? '#E8F5E9' : r.status === 'cancelled' ? '#FFEBEE' : '#FFF3E0', color: r.status === 'completed' ? '#2E7D32' : r.status === 'cancelled' ? '#C62828' : '#E65100' }}>{r.status}</span></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}