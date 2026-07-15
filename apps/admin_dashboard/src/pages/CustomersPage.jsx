import React, { useState, useEffect } from 'react';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function CustomersPage() {
  const [customers, setCustomers] = useState([]);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        const res = await fetch(API + '/admin/customers?limit=100', { headers: { Authorization: 'Bearer ' + token } });
        const data = await res.json();
        if (data.success && Array.isArray(data.data)) setCustomers(data.data);
      } catch (e) {}
    };
    load();
  }, []);

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>Customer Management</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Total: {customers.length} customer(s)</p>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white', borderRadius: 8, overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
        <thead>
          <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
            <th style={{ padding: 12 }}>Name</th>
            <th style={{ padding: 12 }}>Phone</th>
            <th style={{ padding: 12 }}>Rides</th>
            <th style={{ padding: 12 }}>Spent</th>
            <th style={{ padding: 12 }}>Rating</th>
          </tr>
        </thead>
        <tbody>
          {customers.length === 0 && <tr><td colSpan="5" style={{ padding: 24, textAlign: 'center', color: '#999' }}>No customers yet. Ask users to register!</td></tr>}
          {customers.map(c => (
            <tr key={c.id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={{ padding: 12 }}>{c.user ? c.user.full_name : 'N/A'}</td>
              <td style={{ padding: 12 }}>{c.user ? c.user.phone : 'N/A'}</td>
              <td style={{ padding: 12 }}>{c.total_rides || 0}</td>
              <td style={{ padding: 12 }}>Rs {c.total_spent || 0}</td>
              <td style={{ padding: 12 }}>{c.rating || '0.0'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}