import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, TextField, InputAdornment, Dialog, DialogTitle, DialogContent, DialogActions, Divider, IconButton } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { Search, CheckCircle, Cancel, Visibility, Close } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function DriversPage() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState('');
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState('');
  const [docDialog, setDocDialog] = useState(null);
  const [rejectReason, setRejectReason] = useState('');
  const [showReject, setShowReject] = useState(null);
  const navigate = useNavigate();

  const load = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) return;
      let url = API + '/admin/drivers?limit=100';
      if (filter) url += '&status=' + filter;
      if (search) url += '&search=' + encodeURIComponent(search);
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
      if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
      const data = await res.json();
      if (data.success && Array.isArray(data.data)) setDrivers(data.data);
    } catch (e) {}
  };

  useEffect(() => { load(); }, [filter, search]);

  const approve = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/approve', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Driver approved!'); setDocDialog(null); load();
  };

  const reject = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/reject', { method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ reason: rejectReason || 'Documents rejected' }) });
    setMsg('Driver rejected!'); setDocDialog(null); setShowReject(null); setRejectReason(''); load();
  };

  const statusColor = (s) => s === 'approved' ? 'success' : s === 'pending' ? 'warning' : 'error';

  const openDocs = async (driverId) => {
    try {
      const token = localStorage.getItem('admin_token');
      const res = await fetch(API + '/admin/drivers/' + driverId, { headers: { Authorization: 'Bearer ' + token } });
      const data = await res.json();
      if (data.success && data.data?.driver) setDocDialog(data.data.driver);
    } catch (e) {}
  };

  const docLabels = { aadhaar_front: 'Aadhaar (Front)', aadhaar_back: 'Aadhaar (Back)', selfie: 'Live Photo', rc: 'Vehicle RC', insurance: 'Vehicle Insurance' };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>Driver Management</Typography>
      {msg && <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>{msg}</Typography>}

      <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        {['','pending','approved','rejected','suspended'].map(f => (
          <Button key={f} size="small" variant={filter === f ? 'contained' : 'outlined'} onClick={() => setFilter(f)}>{f || 'All'}</Button>
        ))}
        <Box sx={{ flexGrow: 1 }} />
        <TextField size="small" placeholder="Search name/phone..." value={search} onChange={e => setSearch(e.target.value)}
          InputProps={{ startAdornment: <InputAdornment position="start"><Search fontSize="small" /></InputAdornment> }} sx={{ minWidth: 200 }} />
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{drivers.length} driver(s)</Typography>

      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>Name</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Phone</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Online</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Docs</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Fee</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Rides</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {drivers.length === 0 && <TableRow><TableCell colSpan={8} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No drivers found</TableCell></TableRow>}
            {drivers.map(d => (
              <TableRow key={d.id} hover sx={{ cursor: 'pointer' }} onClick={() => navigate('/drivers/' + d.id)}>
                <TableCell>{d.user ? d.user.full_name : 'N/A'}</TableCell>
                <TableCell>{d.user ? d.user.phone : 'N/A'}</TableCell>
                <TableCell><Chip label={d.registration_status} color={statusColor(d.registration_status)} size="small" /></TableCell>
                <TableCell><Chip label={d.is_online ? 'Online' : 'Offline'} color={d.is_online ? 'success' : 'default'} size="small" variant="outlined" /></TableCell>
                <TableCell>
                  <Chip label={d.is_documents_uploaded ? 'Yes' : 'No'} size="small" color={d.is_documents_uploaded ? 'info' : 'default'} variant="outlined"
                    onClick={(e) => { e.stopPropagation(); if (d.is_documents_uploaded) openDocs(d.id); }}
                    sx={{ cursor: d.is_documents_uploaded ? 'pointer' : 'default' }} icon={d.is_documents_uploaded ? <Visibility fontSize="small" /> : undefined} />
                </TableCell>
                <TableCell>{d.registration_fee_paid ? 'Paid' : 'Pending'}</TableCell>
                <TableCell>{d.total_rides || 0}</TableCell>
                <TableCell onClick={e => e.stopPropagation()}>
                  {d.registration_status === 'pending' && (
                    <Box sx={{ display: 'flex', gap: 0.5 }}>
                      <Button size="small" color="info" variant="outlined" onClick={() => openDocs(d.id)} sx={{ minWidth: 0, p: '4px 8px' }}><Visibility fontSize="small" /></Button>
                      <Button size="small" color="success" variant="contained" onClick={() => approve(d.id)} sx={{ minWidth: 0, p: '4px 8px' }}><CheckCircle fontSize="small" /></Button>
                      <Button size="small" color="error" variant="contained" onClick={() => setShowReject(d.id)} sx={{ minWidth: 0, p: '4px 8px' }}><Cancel fontSize="small" /></Button>
                    </Box>
                  )}
                  {d.registration_status === 'approved' && <Chip label="Active" color="success" size="small" />}
                  {d.registration_status === 'rejected' && <Chip label="Rejected" color="error" size="small" />}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Documents Dialog */}
      <Dialog open={!!docDialog} onClose={() => setDocDialog(null)} maxWidth="md" fullWidth>
        {docDialog && (
          <>
            <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span><strong>{docDialog.user?.full_name || 'Driver'}</strong> - Document Verification</span>
              <IconButton size="small" onClick={() => setDocDialog(null)}><Close /></IconButton>
            </DialogTitle>
            <DialogContent dividers>
              {/* Personal Info Summary */}
              <Box sx={{ mb: 2, p: 2, bgcolor: '#F5F6FA', borderRadius: 2, display: 'flex', gap: 3, flexWrap: 'wrap' }}>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>📞 {docDialog.user?.phone || 'N/A'}</Typography>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>Status: <Chip label={docDialog.registration_status} color={statusColor(docDialog.registration_status)} size="small" /></Typography>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>Fee: {docDialog.registration_fee_paid ? '✅ Paid' : '❌ Pending'}</Typography>
              </Box>

              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>📸 Uploaded Documents</Typography>
              {(docDialog.documents || []).length === 0 && <Typography color="text.secondary">No documents uploaded</Typography>}
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {(docDialog.documents || []).map((doc, i) => {
                  const isImage = doc.document_url && (doc.document_url.startsWith('data:image') || doc.document_url.match(/\.(jpg|jpeg|png|gif)$/i));
                  return (
                    <Box key={i} sx={{ p: 2, bgcolor: '#FAFAFA', borderRadius: 2, border: '1px solid #eee' }}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>{docLabels[doc.document_type] || doc.document_type}</Typography>
                        <Chip label={doc.status || 'pending'} size="small" color={doc.status === 'approved' ? 'success' : doc.status === 'rejected' ? 'error' : 'warning'} />
                      </Box>
                      {isImage ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', bgcolor: '#fff', borderRadius: 1, p: 1, border: '1px solid #ddd' }}>
                          <img src={doc.document_url} alt={doc.document_type} style={{ maxWidth: '100%', maxHeight: 300, objectFit: 'contain', borderRadius: 4 }} />
                        </Box>
                      ) : (
                        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', p: 4, bgcolor: '#fff', borderRadius: 1, border: '1px solid #ddd', color: '#999' }}>
                          <Typography>No image available</Typography>
                        </Box>
                      )}
                    </Box>
                  );
                })}
              </Box>

              {/* Vehicle Info */}
              {docDialog.vehicle && (
                <>
                  <Divider sx={{ my: 2 }} />
                  <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>Vehicle Info</Typography>
                  <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                    <Chip label={`Number: ${docDialog.vehicle.vehicle_number || 'N/A'}`} variant="outlined" size="small" />
                    <Chip label={`Model: ${docDialog.vehicle.vehicle_model || 'N/A'}`} variant="outlined" size="small" />
                  </Box>
                </>
              )}
            </DialogContent>
            <DialogActions sx={{ p: 2, gap: 1 }}>
              {docDialog.registration_status === 'pending' && (
                <>
                  <Button variant="contained" color="success" onClick={() => approve(docDialog.id)} startIcon={<CheckCircle />}>Approve</Button>
                  <Button variant="contained" color="error" onClick={() => { setDocDialog(null); setShowReject(docDialog.id); }} startIcon={<Cancel />}>Reject</Button>
                </>
              )}
              <Button onClick={() => setDocDialog(null)}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Reject Reason Dialog */}
      <Dialog open={!!showReject} onClose={() => { setShowReject(null); setRejectReason(''); }} maxWidth="xs" fullWidth>
        <DialogTitle>Reject Driver</DialogTitle>
        <DialogContent>
          <TextField autoFocus fullWidth multiline rows={3} label="Rejection Reason" value={rejectReason} onChange={e => setRejectReason(e.target.value)} sx={{ mt: 1 }} placeholder="Documents rejected" />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => { setShowReject(null); setRejectReason(''); }}>Cancel</Button>
          <Button variant="contained" color="error" onClick={() => reject(showReject)}>Reject Driver</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
