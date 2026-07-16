import React, { useState, useEffect } from 'react';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function SupportPage() {
  const [tickets, setTickets] = useState([]);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        const res = await fetch(API + '/admin/support-tickets', { headers: { Authorization: 'Bearer ' + token } });
        const data = await res.json();
        if (data.success && data.data && data.data.tickets) setTickets(data.data.tickets);
      } catch (e) {}
    };
    load();
  }, []);

  const updateStatus = async (id, status) => {
    try {
      const token = localStorage.getItem('admin_token');
      await fetch(API + '/admin/support-tickets/' + id, {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      setTickets(tickets.map(t => t.id === id ? { ...t, status } : t));
    } catch (e) {}
  };

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>Support Tickets</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Total: {tickets.length} ticket(s)</p>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white', borderRadius: 8, overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
        <thead>
          <tr style={{ background: '#f5f5f5', textAlign: 'left' }}>
            <th style={{ padding: 12 }}>User</th>
            <th style={{ padding: 12 }}>Subject</th>
            <th style={{ padding: 12 }}>Status</th>
            <th style={{ padding: 12 }}>Priority</th>
            <th style={{ padding: 12 }}>Date</th>
            <th style={{ padding: 12 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {tickets.length === 0 && <tr><td colSpan="6" style={{ padding: 24, textAlign: 'center', color: '#999' }}>No tickets yet.</td></tr>}
          {tickets.map(t => (
            <tr key={t.id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={{ padding: 12 }}>{t.user?.full_name || 'N/A'}<br/><small>{t.user?.phone || ''}</small></td>
              <td style={{ padding: 12 }}>{t.subject}</td>
              <td style={{ padding: 12 }}>
                <span style={{ color: t.status === 'open' ? 'orange' : t.status === 'resolved' ? 'green' : 'blue', fontWeight: 'bold' }}>{t.status}</span>
              </td>
              <td style={{ padding: 12 }}>
                <span style={{ color: t.priority === 'urgent' ? 'red' : t.priority === 'high' ? 'orange' : 'blue' }}>{t.priority}</span>
              </td>
              <td style={{ padding: 12 }}>{new Date(t.created_at).toLocaleDateString()}</td>
              <td style={{ padding: 12 }}>
                {t.status === 'open' && (
                  <button onClick={() => updateStatus(t.id, 'resolved')} style={{ padding: '4px 12px', background: 'green', color: 'white', border: 'none', borderRadius: 4, cursor: 'pointer' }}>
                    Resolve
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}