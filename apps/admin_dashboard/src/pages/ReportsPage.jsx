import React, { useState } from "react";
import { Box, Typography, Card, CardContent, Button, Grid } from "@mui/material";
import { Download, People, DirectionsCar, AttachMoney } from "@mui/icons-material";

const API = "https://zip-rick-4.onrender.com/api/v1";

export default function ReportsPage() {
  const token = localStorage.getItem("admin_token");

  const download = async (type) => {
    try {
      const res = await fetch(API + "/admin/reports/" + type, {
        headers: { Authorization: "Bearer " + token },
      });
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = type + ".csv";
      a.click();
    } catch (e) {}
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>
        Reports & Exports
      </Typography>
      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ cursor: "pointer" }} onClick={() => download("customers")}>
            <CardContent sx={{ textAlign: "center", py: 4 }}>
              <People sx={{ fontSize: 48, color: "#6C63FF", mb: 1 }} />
              <Typography variant="h6">Customers</Typography>
              <Typography variant="body2" color="text.secondary">Download CSV</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ cursor: "pointer" }} onClick={() => download("drivers")}>
            <CardContent sx={{ textAlign: "center", py: 4 }}>
              <DirectionsCar sx={{ fontSize: 48, color: "#4CAF50", mb: 1 }} />
              <Typography variant="h6">Drivers</Typography>
              <Typography variant="body2" color="text.secondary">Download CSV</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ cursor: "pointer" }} onClick={() => download("rides")}>
            <CardContent sx={{ textAlign: "center", py: 4 }}>
              <DirectionsCar sx={{ fontSize: 48, color: "#FFA726", mb: 1 }} />
              <Typography variant="h6">Rides</Typography>
              <Typography variant="body2" color="text.secondary">Download CSV</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ cursor: "pointer" }} onClick={() => download("revenue")}>
            <CardContent sx={{ textAlign: "center", py: 4 }}>
              <AttachMoney sx={{ fontSize: 48, color: "#f44336", mb: 1 }} />
              <Typography variant="h6">Revenue</Typography>
              <Typography variant="body2" color="text.secondary">Download CSV</Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
