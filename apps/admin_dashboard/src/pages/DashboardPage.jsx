import React, { useState, useEffect } from 'react';
import { Box, Grid, Card, CardContent, Typography, Button, CircularProgress } from '@mui/material';
import { People, DirectionsCar, WarningAmber, AttachMoney, TrendingUp, Today, OnlinePrediction } from '@mui/icons-material';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const API = 'https://zip-rick-4.onrender.com/api/v1';

function StatCard({ title, value, icon, color, subtitle }) {
  return (
    <Card sx={{ height: '100%' }}>
      <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2, p: 3 }}>
        <Box sx={{ width: 52, height: 52, borderRadius: 2, display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: color + '20' }}>
          {React.cloneElement(icon, { sx: { color, fontSize: 28 } })}
        </Box>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 700 }}>{value}</Typography>
          <Typography variant="body2" color="text.secondary">{title}</Typography>
          {subtitle && <Typography variant="caption" color="text.secondary">{subtitle}</Typography>}
        </Box>
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const [stats, setStats] = useState(null);
  const [error, setError] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const loadData = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) { setError('Not logged in'); return; }
      const res = await fetch(API + '/admin/dashboard', { headers: { Authorization: 'Bearer ' + token } });
      if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
      const data = await res.json();
      if (data.success && data.data && data.data.overview) {
        setStats(data.data.overview);
        setError('');
      } else { setError('Failed to load data'); }
    } catch (e) { setError('Network error'); }
  };

  useEffect(() => { loadData(); const t = setInterval(loadData, 30000); return () => clearInterval(t); }, []);

  if (!stats) return <Box sx={{ display: 'flex', justifyContent: 'center', p: 8 }}><CircularProgress /></Box>;

  const chartData = (stats.revenue_chart || []).map(d => ({
    day: d.date ? d.date.slice(5) : '',
    revenue: parseFloat(d.total_revenue || 0),
  }));
  // If no data, show last 7 days with zeroes
  if (chartData.length === 0) {
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dayStr = d.toLocaleDateString('en-IN', { weekday: 'short', month: 'short', day: 'numeric' });
      chartData.push({ day: dayStr, revenue: 0 });
    }
  } else {
    // Show last 7 days from real data
    chartData = chartData.slice(-7);
  }

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 700 }}>Dashboard</Typography>
        <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
          <Typography variant="body2" color="text.secondary">Auto-refreshes every 30s</Typography>
          <Button size="small" variant="outlined" onClick={() => { setRefreshing(true); loadData().then(() => setRefreshing(false)); }} disabled={refreshing}>Refresh</Button>
        </Box>
      </Box>
      {error && <Typography color="error" sx={{ mb: 2 }}>{error}</Typography>}

      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Customers" value={stats.total_customers || 0} icon={<People />} color="#6C63FF" />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Drivers" value={stats.total_drivers || 0} icon={<DirectionsCar />} color="#00D9A6" subtitle={`${stats.online_drivers || 0} online, ${stats.on_ride_drivers || 0} on ride`} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Pending Approvals" value={stats.pending_drivers || 0} icon={<WarningAmber />} color="#FFA726" />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Active Rides" value={stats.active_rides || 0} icon={<TrendingUp />} color="#66BB6A" />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Today Rides" value={stats.today_rides || 0} icon={<Today />} color="#42A5F5" />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Revenue" value={`₹${(stats.revenue?.total || 0).toLocaleString()}`} icon={<AttachMoney />} color="#FF7043" subtitle={`Today: ₹${(stats.revenue?.today || 0).toLocaleString()}`} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Online Drivers" value={stats.online_drivers || 0} icon={<OnlinePrediction />} color="#4CAF50" subtitle={`Offline: ${stats.offline_drivers || 0}`} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Total Rides" value={stats.total_rides || 0} icon={<DirectionsCar />} color="#AB47BC" />
        </Grid>
      </Grid>

      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>Revenue (Last 30 Days)</Typography>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" fontSize={12} />
              <YAxis fontSize={12} />
              <Tooltip />
              <Bar dataKey="revenue" fill="#6C63FF" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </Box>
  );
}
