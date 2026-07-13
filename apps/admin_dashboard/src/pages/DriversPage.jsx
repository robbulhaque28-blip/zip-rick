import React, { useState, useEffect } from 'react';

const API = 'http://localhost:3000/api/v1';

export default function DriversPage() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState('');
  const [msg, setMsg] = useState('');

  const load = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) return;
      let url = API + '/admin/drivers?limit=100';
      if (filter) url += '&status=' + filter;
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
      const data = await res.json();
      if (data.success && Array.isArray(data.data)) setDrivers(data.data);
    } catch (e) {}
  };

  useEffect(() => { load(); }, [filter]);

  const approve = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/approve', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Driver approved!');
    load();
  };

  const reject = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/reject', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Driver rejected!');
    load();
  };

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>Driver Management</h1>
      {msg && <div style={{ padding: 8, background: '#E8F5E9', borderRadius: 8, marginBottom: 12, color: '#2E7D32' }}>{msg}</div>}
      <div style={{ marginBottom: 16 }}>
        <button onClick={() => setFilter('')} style={{ padding: '8px 16px', marginRight: 8, background: filter === '' ? '#6C63FF' : '#e0e0e0', color: filter === '' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>All</button>
        <button onClick={() => setFilter('pending')} style={{ padding: '8px 16px', marginRight: 8, background: filter === 'pending' ? '#6C63FF' : '#e0e0e0', color: filter === 'pending' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>Pending</button>
        <button onClick={() => setFilter('approved')} style={{ padding: '8px 16px', marginRight: 8, background: filter === 'approved' ? '#6C63FF' : '#e0e0e0', color: filter === 'approved' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>Approved</button>
        <button onClick={() => setFilter('rejected')} style={{ padding: '8px 16px', background: filter === 'rejected' ? '#6C63FF' : '#e0e0e0', color: filter === 'rejected' ? 'white' : 'black', border: 'none', borderRadius: 4, cursor: 'pointer' }}>Rejected</button>
      </div>
      <p style={{ color: '#666', marginBottom: 12 }}>{drivers.length} driver(s) found</p>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white', borderRadius: 8, overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
        <thead>
          <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
            <th style={{ padding: 12 }}>Name</th>
            <th style={{ padding: 12 }}>Phone</th>
            <th style={{ padding: 12 }}>Status</th>
            <th style={{ padding: 12 }}>Docs</th>
            <th style={{ padding: 12 }}>Fee</th>
            <th style={{ padding: 12 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {drivers.length === 0 && <tr><td colSpan="6" style={{ padding: 24, textAlign: 'center', color: '#999' }}>No drivers found</td></tr>}
          {drivers.map(d => (
            <tr key={d.id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={{ padding: 12 }}>{d.user ? d.user.full_name : 'N/A'}</td>
              <td style={{ padding: 12 }}>{d.user ? d.user.phone : 'N/A'}</td>
              <td style={{ padding: 12 }}><span style={{ padding: '2px 8px', borderRadius: 4, background: d.registration_status === 'approved' ? '#E8F5E9' : d.registration_status === 'pending' ? '#FFF3E0' : '#FFEBEE', color: d.registration_status === 'approved' ? '#2E7D32' : d.registration_status === 'pending' ? '#E65100' : '#C62828' }}>{d.registration_status}</span></td>
              <td style={{ padding: 12 }}>{d.is_documents_uploaded ? 'Yes' : 'No'}</td>
              <td style={{ padding: 12 }}>{d.registration_fee_paid ? 'Paid' : 'Pending'}</td>
              <td style={{ padding: 12 }}>
                {d.registration_status === 'pending' && (
                  <>
                    <button onClick={() => approve(d.id)} style={{ padding: '6px 16px', background: '#4CAF50', color: 'white', border: 'none', borderRadius: 4, cursor: 'pointer', marginRight: 8 }}>Approve</button>
                    <button onClick={() => reject(d.id)} style={{ padding: '6px 16px', background: '#f44336', color: 'white', border: 'none', borderRadius: 4, cursor: 'pointer' }}>Reject</button>
                  </>
                )}
                {d.registration_status === 'approved' && <span style={{ color: '#4CAF50', fontWeight: 'bold' }}>Active</span>}
                {d.registration_status === 'rejected' && <span style={{ color: '#f44336' }}>Rejected</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}