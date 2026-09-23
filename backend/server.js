const path = require('path');
const dotenv = require('dotenv');

// Absolute path so `.env` loads even when the CWD differs.
dotenv.config({ path: path.join(__dirname, '.env') });

const express = require('express');
const cors = require('cors');
const connectDB = require('./config/database');
const authRoutes = require('./routes/authRoutes');
const managedEventRoutes = require('./routes/managedEventRoutes');
const feedPostRoutes = require('./routes/feedPostRoutes');
const sessionContentRoutes = require('./routes/sessionContentRoutes');

if (!process.env.JWT_SECRET) {
  console.error('Error: JWT_SECRET is not set in .env');
  process.exit(1);
}

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => res.json({ message: 'ISDR2026 API running' }));
app.get('/api/health', (req, res) => res.json({ success: true, status: 'ok' }));

app.use('/api/auth', authRoutes);
app.use('/api/managed-events', managedEventRoutes);
app.use('/api/feed-posts', feedPostRoutes);
app.use('/api/session-content', sessionContentRoutes);

// 404
app.use((req, res) => {
  res.status(404).json({ error: `Not found: ${req.originalUrl}` });
});

// Error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Server error' });
});

const PORT = process.env.PORT || 5000;

connectDB().then(() => {
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
});
