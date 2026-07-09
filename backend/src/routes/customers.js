const router = require('express').Router();

// Placeholder customers routes
router.get('/', (req, res) => {
  res.json({ message: 'Customers routes' });
});

module.exports = router;
