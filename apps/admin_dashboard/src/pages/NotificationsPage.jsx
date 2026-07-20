import React, { useState } from 'react';
import { Box, Typography, Button, TextField, Select, MenuItem, Card, CardContent, FormControl, InputLabel, CircularProgress } from '@mui/material';
import { Send } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function NotificationsPage() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [target, setTarget] = useState('all');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState('');

  const sendNotification = async () => {
    if (!message.trim()) return;
    setSending(true);
    setResult('');
    try {
      const token = localStorage.getItem('admin_token');
      const res = await fetch(API + '/admin/notifications/broadcast', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, message, target_role: target }),
      });
      const data = await res.json();
      if (data.success) setResult(`Notification sent to ${data.data?.sent || 0} user(s)!`);
      else setResult('Failed to send');
    } catch (e) {
      setResult('Network error');
    }
    setSending(false);
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>Send Notification</Typography>
      <Card sx={{ maxWidth: 600 }}>
        <CardContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, p: 3 }}>
          <TextField label="Title (optional)" value={title} onChange={e => setTitle(e.target.value)} />
          <TextField label="Message *" multiline rows={4} value={message} onChange={e => setMessage(e.target.value)} />
          <FormControl>
            <InputLabel>Target</InputLabel>
            <Select value={target} onChange={e => setTarget(e.target.value)} label="Target">
              <MenuItem value="all">All Users</MenuItem>
              <MenuItem value="drivers">All Drivers</MenuItem>
              <MenuItem value="customers">All Customers</MenuItem>
            </Select>
          </FormControl>
          {result && <Typography sx={{ p: 1.5, bgcolor: result.includes('sent') ? '#E8F5E9' : '#FFEBEE', borderRadius: 2, color: result.includes('sent') ? '#2E7D32' : '#C62828' }}>{result}</Typography>}
          <Button variant="contained" startIcon={sending ? <CircularProgress size={20} color="inherit" /> : <Send />} onClick={sendNotification} disabled={sending || !message.trim()} sx={{ alignSelf: 'flex-start' }}>
            {sending ? 'Sending...' : 'Broadcast'}
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
}
