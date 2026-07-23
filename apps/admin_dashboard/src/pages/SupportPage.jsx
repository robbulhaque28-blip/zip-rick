import React, { useState, useEffect, useRef } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, Badge } from '@mui/material';
import { Warning, NotificationsActive } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

// Generate a beep sound using Web Audio API (no external files needed)
function playSOSBeep() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.frequency.value = 880;
    osc.type = 'sine';
    gain.gain.setValueAtTime(0.5, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.5);

    // Second beep
    setTimeout(() => {
      const ctx2 = new (window.AudioContext || window.webkitAudioContext)();
      const osc2 = ctx2.createOscillator();
      const gain2 = ctx2.createGain();
      osc2.connect(gain2);
      gain2.connect(ctx2.destination);
      osc2.frequency.value = 880;
      osc2.type = 'sine';
      gain2.gain.setValueAtTime(0.5, ctx2.currentTime);
      gain2.gain.exponentialRampToValueAtTime(0.01, ctx2.currentTime + 0.5);
      osc2.start(ctx2.currentTime);
      osc2.stop(ctx2.currentTime + 0.5);
    }, 600);

    // Third beep
    setTimeout(() => {
      const ctx3 = new (window.AudioContext || window.webkitAudioContext)();
      const osc3 = ctx3.createOscillator();
      const gain3 = ctx3.createGain();
      osc3.connect(gain3);
      gain3.connect(ctx3.destination);
      osc3.frequency.value = 660;
      osc3.type = 'sine';
      gain3.gain.setValueAtTime(0.5, ctx3.currentTime);
      gain3.gain.exponentialRampToValueAtTime(0.01, ctx3.currentTime + 0.5);
      osc3.start(ctx3.currentTime);
      osc3.stop(ctx3.currentTime + 0.5);
    }, 1200);
  } catch (e) {
    // Audio not supported - silently fail
  }
}

function showBrowserNotification(title, body) {
  try {
    // Check if browser supports notifications
    if (!('Notification' in window)) return;
    
    // Request permission if needed
    if (Notification.permission === 'granted') {
      new Notification(title, {
        body: body,
        icon: '/favicon.png',
        tag: 'sos-alert',
        requireInteraction: true,
      });
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then(permission => {
        if (permission === 'granted') {
          new Notification(title, {
            body: body,
            icon: '/favicon.png',
            tag: 'sos-alert',
            requireInteraction: true,
          });
        }
      });
    }
  } catch (e) {
    // Notifications not supported
  }
}

export default function SupportPage() {
  const [tickets, setTickets] = useState([]);
  const [filter, setFilter] = useState('');
  const prevSOSCount = useRef(0);
  const audioEnabled = useRef(true);

  useEffect(() => {
    // Request notification permission on mount
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
  }, []);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        let url = API + '/admin/support-tickets';
        if (filter) url += '?status=' + filter;
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
        if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
        const data = await res.json();
        if (data.success && data.data && data.data.tickets) {
          const newTickets = data.data.tickets;
          const newSOSCount = newTickets.filter(t => t.priority === 'urgent' && t.status === 'open').length;
          
          // Check for new SOS tickets
          if (newSOSCount > prevSOSCount.current && prevSOSCount.current !== -1) {
            const newSOS = newTickets.filter(t => t.priority === 'urgent' && t.status === 'open');
            if (newSOS.length > 0) {
              const latest = newSOS[0];
              // Play sound
              if (audioEnabled.current) playSOSBeep();
              // Show browser notification
              showBrowserNotification(
                '🚨 SOS Emergency Alert!',
                `${latest.user?.full_name || 'Unknown'} needs help!\nPhone: ${latest.user?.phone || 'N/A'}\nSubject: ${latest.subject || 'Emergency'}`
              );
            }
          }
          prevSOSCount.current = newSOSCount;
          setTickets(newTickets);
        }
      } catch (e) {}
    };
    // Initialize prev count
    if (prevSOSCount.current === 0) prevSOSCount.current = -1;
    load();
    const t = setInterval(load, 10000); // Check every 10 seconds
    return () => clearInterval(t);
  }, [filter]);

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

  const sosCount = tickets.filter(t => t.priority === 'urgent' && t.status === 'open').length;

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h4" sx={{ fontWeight: 700 }}>
          Support Tickets
          {sosCount > 0 && (
            <Chip label={`${sosCount} SOS`} color="error" size="medium" icon={<Warning />} sx={{ ml: 2, fontWeight: 700 }} />
          )}
        </Typography>
        <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
          <Button
            size="small"
            variant={audioEnabled.current ? 'contained' : 'outlined'}
            color={audioEnabled.current ? 'success' : 'default'}
            onClick={() => audioEnabled.current = !audioEnabled.current}
            startIcon={<NotificationsActive />}
          >
            {audioEnabled.current ? 'Sound ON' : 'Sound OFF'}
          </Button>
        </Box>
      </Box>

      {sosCount > 0 && (
        <Box sx={{ p: 2, mb: 2, bgcolor: '#FFF0F0', borderRadius: 2, border: '2px solid #f44336', display: 'flex', alignItems: 'center', gap: 1 }}>
          <Warning sx={{ color: '#f44336', fontSize: 28 }} />
          <Typography sx={{ color: '#f44336', fontWeight: 700 }}>
            {sosCount} SOS emergency ticket(s) waiting! Check them immediately!
          </Typography>
        </Box>
      )}

      <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
        {['','open','resolved','closed'].map(f => (
          <Button key={f} size="small" variant={filter === f ? 'contained' : 'outlined'} onClick={() => setFilter(f)}
            color={f === '' && sosCount > 0 ? 'error' : 'primary'}>
            {f || 'All'}
          </Button>
        ))}
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{tickets.length} ticket(s)</Typography>
      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>User</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Subject</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Priority</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Date</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {tickets.length === 0 && <TableRow><TableCell colSpan={6} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No tickets</TableCell></TableRow>}
            {tickets.map(t => (
              <TableRow key={t.id} sx={{ bgcolor: t.priority === 'urgent' ? '#FFF0F0' : 'inherit' }}>
                <TableCell>
                  {t.priority === 'urgent' && <Badge color="error" variant="dot" sx={{ mr: 1 }} />}
                  {t.user?.full_name || 'N/A'}<br /><Typography variant="caption" color="text.secondary">{t.user?.phone || ''}</Typography>
                </TableCell>
                <TableCell sx={{ fontWeight: t.priority === 'urgent' ? 600 : 400 }}>{t.subject}</TableCell>
                <TableCell><Chip label={t.status} size="small" color={t.status === 'open' ? 'warning' : t.status === 'resolved' ? 'success' : 'default'} /></TableCell>
                <TableCell><Chip label={t.priority} size="small" color={t.priority === 'urgent' ? 'error' : t.priority === 'high' ? 'warning' : 'info'} /></TableCell>
                <TableCell>{t.created_at ? new Date(t.created_at).toLocaleString() : ''}</TableCell>
                <TableCell>
                  {t.status === 'open' && (
                    <Button size="small" color="success" variant="contained" onClick={() => updateStatus(t.id, 'resolved')} sx={{ mr: 0.5 }}>
                      Resolve
                    </Button>
                  )}
                  {t.status === 'resolved' && <Button size="small" onClick={() => updateStatus(t.id, 'open')}>Reopen</Button>}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
