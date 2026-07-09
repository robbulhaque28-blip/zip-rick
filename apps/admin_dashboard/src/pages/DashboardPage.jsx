import React, { useState, useEffect } from 'react';
import { Box, Grid, Card, CardContent, Typography, Select, MenuItem, FormControl } from '@mui/material';
import { PeopleAlt, DirectionsCar, AttachMoney } from '@mui/icons-material';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const API = 'http://localhost:4001/api/v1';

export default function DashboardPage() {
  const [period, setPeriod] = useState('7');
  const [stats, setStats] = useState({ total_customers: 0, total_drivers: 0, active_rides: 0, revenue: { today: 0 } });

  useEffect(() => {
    fetch(API + '/admin/dashboard')
      .then(r => r.json())
      .then(d => { if (d.data?.overview) setStats(d.data.overview); })
      .catch(() => {});
  }, []);

  const chartData = [
    { day: 'Mon', revenue: 4500, rides: 45 }, { day: 'Tue', revenue: 5200, rides: 52 },
    { day: 'Wed', revenue: 4800, rides: 48 }, { day: 'Thu', revenue: 6100, rides: 61 },
    { day: 'Fri', revenue: 7200, rides: 72 }, { day: 'Sat', revenue: 8900, rides: 89 },
    { day: 'Sun', revenue: 5600, rides: 56 },
  ];

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
        {[
          { title: 'Total Customers', value: (stats.total_customers || 0).toLocaleString(), icon: <PeopleAlt />, color: '#6C63FF' },
          { title: 'Total Drivers', value: (stats.total_drivers || 0).toLocaleString(), icon: <DirectionsCar />, color: '#00D9A6' },
          { title: 'Active Rides', value: (stats.active_rides || 0).toString(), icon: <DirectionsCar />, color: '#FFA726' },
          { title: 'Revenue Today', value: '\u20B9' + (stats.revenue?.today || 0).toLocaleString(), icon: <AttachMoney />, color: '#66BB6A' },
        ].map((s, i) => (
          <Grid item xs={12} sm={6} md={3} key={i}>
            <Card sx={{ p: 3 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <Box><Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{s.title}</Typography>
                <Typography variant="h4" sx={{ fontWeight: 700 }}>{s.value}</Typography></Box>
                <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: s.color + '15', color: s.color }}>{s.icon}</Box>
              </Box>
            </Card>
          </Grid>
        ))}
      </Grid>
      <Card><CardContent>
        <Typography variant="h6" sx={{ mb: 2 }}>Revenue & Rides</Typography>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" /><XAxis dataKey="day" /><YAxis /><Tooltip />
            <Bar dataKey="revenue" fill="#6C63FF" radius={[4,4,0,0]} name="Revenue" />
            <Bar dataKey="rides" fill="#00D9A6" radius={[4,4,0,0]} name="Rides" />
          </BarChart>
        </ResponsiveContainer>
      </CardContent></Card>
    </Box>
  );
}
