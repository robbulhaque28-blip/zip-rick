const router = require('express').Router();

// Placeholder drivers routes
router.get('/', (req, res) => {
  res.json({ message: 'Drivers routes' });
});

module.exports = router;
