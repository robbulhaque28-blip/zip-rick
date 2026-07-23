import React, { useState } from "react";
import { Box, Typography, Button, Grid, Card, CardContent, TextField, ToggleButton, ToggleButtonGroup, Dialog, DialogTitle, DialogContent, DialogActions } from "@mui/material";
import { Download, PictureAsPdf, TableChart, People, DirectionsCar, AttachMoney, CalendarMonth } from "@mui/icons-material";

const API = "https://zip-rick-4.onrender.com/api/v1";

const periods = [
  { value: "1m", label: "Last Month" },
  { value: "3m", label: "Last 3 Months" },
  { value: "6m", label: "Last 6 Months" },
  { value: "custom", label: "Custom" },
];

const reportTypes = [
  { key: "customers", label: "Customers", icon: <People sx={{ fontSize: 40 }} />, color: "#6C63FF" },
  { key: "drivers", label: "Drivers", icon: <DirectionsCar sx={{ fontSize: 40 }} />, color: "#4CAF50" },
  { key: "rides", label: "Rides", icon: <DirectionsCar sx={{ fontSize: 40 }} />, color: "#FFA726" },
  { key: "revenue", label: "Revenue", icon: <AttachMoney sx={{ fontSize: 40 }} />, color: "#f44336" },
];

function formatDate(d) {
  return d.toISOString().split("T")[0];
}

export default function ReportsPage() {
  const token = localStorage.getItem("admin_token");
  const [period, setPeriod] = useState("1m");
  const [customStart, setCustomStart] = useState("");
  const [customEnd, setCustomEnd] = useState("");
  const [previewHtml, setPreviewHtml] = useState(null);
  const [previewTitle, setPreviewTitle] = useState("");

  const getDateRange = () => {
    const now = new Date();
    let start, end = now;
    if (period === "1m") { start = new Date(now); start.setMonth(start.getMonth() - 1); }
    else if (period === "3m") { start = new Date(now); start.setMonth(start.getMonth() - 3); }
    else if (period === "6m") { start = new Date(now); start.setMonth(start.getMonth() - 6); }
    else if (period === "custom") {
      start = customStart ? new Date(customStart) : new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      end = customEnd ? new Date(customEnd) : now;
    }
    return { start: formatDate(start), end: formatDate(end) };
  };

  const downloadCSV = async (type) => {
    try {
      const { start, end } = getDateRange();
      let url = API + "/admin/reports/" + type;
      if (period !== "1m") url += "?days=" + (period === "3m" ? 90 : period === "6m" ? 180 : 30);
      const res = await fetch(url, { headers: { Authorization: "Bearer " + token } });
      const blob = await res.blob();
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = type + "-report.csv";
      a.click();
    } catch (e) {}
  };

  const previewPDF = async (type) => {
    try {
      const { start, end } = getDateRange();
      const res = await fetch(API + "/admin/reports-pdf/" + type + "?start=" + start + "&end=" + end, {
        headers: { Authorization: "Bearer " + token },
      });
      const html = await res.text();
      setPreviewTitle(type.charAt(0).toUpperCase() + type.slice(1) + " Report");
      setPreviewHtml(html);
    } catch (e) {}
  };

  const downloadPDF = (type) => {
    // Open in new window and print to PDF
    const { start, end } = getDateRange();
    const w = window.open(API + "/admin/reports-pdf/" + type + "?start=" + start + "&end=" + end, "_blank");
    if (w) {
      w.onload = () => { setTimeout(() => { w.print(); }, 500); };
    }
  };

  const printPreview = () => {
    if (previewHtml) {
      const w = window.open("", "_blank");
      w.document.write(previewHtml);
      w.document.close();
      setTimeout(() => { w.print(); }, 500);
    }
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>Reports & Exports</Typography>

      {/* Date Range Selector */}
      <Card sx={{ mb: 4 }}>
        <CardContent sx={{ p: 3 }}>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, display: "flex", alignItems: "center", gap: 1 }}>
            <CalendarMonth /> Select Period
          </Typography>
          <ToggleButtonGroup
            value={period}
            exclusive
            onChange={(e, v) => { if (v) setPeriod(v); }}
            size="small"
            sx={{ mb: period === "custom" ? 2 : 0 }}
          >
            {periods.map(p => (
              <ToggleButton key={p.value} value={p.value} sx={{ px: 3 }}>
                {p.label}
              </ToggleButton>
            ))}
          </ToggleButtonGroup>
          {period === "custom" && (
            <Box sx={{ display: "flex", gap: 2, mt: 2, alignItems: "center" }}>
              <TextField type="date" label="Start Date" value={customStart} onChange={e => setCustomStart(e.target.value)} InputLabelProps={{ shrink: true }} size="small" />
              <Typography>to</Typography>
              <TextField type="date" label="End Date" value={customEnd} onChange={e => setCustomEnd(e.target.value)} InputLabelProps={{ shrink: true }} size="small" />
            </Box>
          )}
        </CardContent>
      </Card>

      {/* Report Cards */}
      <Grid container spacing={3}>
        {reportTypes.map(rt => (
          <Grid item xs={12} sm={6} md={3} key={rt.key}>
            <Card sx={{ height: "100%" }}>
              <CardContent sx={{ textAlign: "center", py: 3 }}>
                <Box sx={{ color: rt.color, mb: 1 }}>{rt.icon}</Box>
                <Typography variant="h6" sx={{ fontWeight: 600 }}>{rt.label}</Typography>
                <Box sx={{ display: "flex", gap: 1, justifyContent: "center", mt: 2 }}>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<TableChart />}
                    onClick={() => downloadCSV(rt.key)}
                    sx={{ fontSize: 12 }}
                  >
                    CSV
                  </Button>
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={<PictureAsPdf />}
                    onClick={() => downloadPDF(rt.key)}
                    sx={{ fontSize: 12, bgcolor: rt.color, "&:hover": { bgcolor: rt.color, opacity: 0.8 } }}
                  >
                    PDF
                  </Button>
                  <Button
                    size="small"
                    variant="text"
                    onClick={() => previewPDF(rt.key)}
                    sx={{ fontSize: 12 }}
                  >
                    Preview
                  </Button>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Preview Dialog */}
      <Dialog open={!!previewHtml} onClose={() => setPreviewHtml(null)} maxWidth="lg" fullWidth>
        <DialogTitle sx={{ fontWeight: 600 }}>{previewTitle} - Preview</DialogTitle>
        <DialogContent sx={{ height: "60vh", overflow: "auto" }}>
          {previewHtml && (
            <iframe
              srcDoc={previewHtml}
              style={{ width: "100%", height: "100%", border: "none" }}
              title="Report Preview"
            />
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPreviewHtml(null)}>Close</Button>
          <Button variant="contained" startIcon={<PictureAsPdf />} onClick={printPreview}>Download as PDF</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
