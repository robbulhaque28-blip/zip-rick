import React, { useState } from 'react';
import { Box, Grid, Card, CardContent, Typography, Select, MenuItem, FormControl } from '@mui/material';
import { PeopleAlt, DirectionsCar, AttachMoney, TrendingUp } from '@mui/icons-material';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useQuery } from 'react-query';
import axios from 'axios';

const API = 'http://localhost:4000/api/v1';

const StatCard = ({ title, value, icon, color }) => (
  <Card sx={{ p: 2 }}>
    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
      <Box>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{title}</Typography>
        <Typography variant="h4" sx={{ fontWeight: 700 }}>{value}</Typography>
      </Box>
      <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: `${color}15` }}><Icon sx={{ color }}>{icon}</Icon></Box>
    </Box>
  </Card>
);

const Icon = ({ children, sx }) => <Box sx={sx}>{children}</Box>;

const stats = [
  { title: 'Total Customers', value: '--', icon: <PeopleAlt />, color: '#6C63FF' },
  { title: 'Total Drivers', value: '--', icon: <DirectionsCar />, color: '#00D9A6' },
  { title: 'Active Rides', value: '--', icon: <DirectionsCar />, color: '#FFA726' },
  { title: 'Revenue Today', value: '--', icon: <AttachMoney />, color: '#66BB6A' },
];

const chartData = [
  { day: 'Mon', revenue: 4500, rides: 45 }, { day: 'Tue', revenue: 5200, rides: 52 },
  { day: 'Wed', revenue: 4800, rides: 48 }, { day: 'Thu', revenue: 6100, rides: 61 },
  { day: 'Fri', revenue: 7200, rides: 72 }, { day: 'Sat', revenue: 8900, rides: 89 },
  { day: 'Sun', revenue: 5600, rides: 56 },
];

export default function DashboardPage() {
  const [period, setPeriod] = useState('7');
  const { data: dashData } = useQuery('dashboard', () =>
    axios.get(`${API}/admin/dashboard`).then(r => r.data.data), { refetchInterval: 30000 });

  const ov = dashData?.overview || {};
  const displayStats = stats.map((s, i) => ({
    ...s,
    value: i === 0 ? (ov.total_customers || 0).toLocaleString()
         : i === 1 ? (ov.total_drivers || 0).toLocaleString()
         : i === 2 ? (ov.active_rides || 0).toLocaleString()
         : `₹${(ov.revenue?.today || 0).toLocaleString()}`
  }));

  return (
    <Box sx={{ p: 3, maxWidth: 1400, mx: 'auto' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">Zip-Rick Dashboard</Typography>
        <FormControl size="small" sx={{ minWidth: 150 }}>
          <Select value={period} onChange={e => setPeriod(e.target.value)}>
            <MenuItem value="7">Last 7 days</MenuItem>
            <MenuItem value="30">Last 30 days</MenuItem>
          </Select>
        </FormControl>
      </Box>
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {displayStats.map((s, i) => (
          <Grid item xs={12} sm={6} md={3} key={i}>
            <StatCard title={s.title} value={s.value} icon={s.icon} color={s.color} />
          </Grid>
        ))}
      </Grid>
      <Card>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2 }}>Revenue & Rides Trend</Typography>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="revenue" fill="#6C63FF" radius={[4,4,0,0]} name="Revenue (₹)" />
              <Bar dataKey="rides" fill="#00D9A6" radius={[4,4,0,0]} name="Rides" />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </Box>
  );
}
