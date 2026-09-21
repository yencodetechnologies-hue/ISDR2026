const dns = require('dns');
const mongoose = require('mongoose');

/**
 * Local router DNS often breaks Node's SRV lookups for mongodb+srv
 * (querySrv ECONNREFUSED). Prefer public resolvers for Atlas discovery.
 */
function ensureReliableDnsForAtlas(uri) {
  if (!uri || !uri.startsWith('mongodb+srv://')) return;
  try {
    dns.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);
  } catch (err) {
    console.warn('[MongoDB] Could not set DNS servers:', err.message);
  }
}

const connectDB = async () => {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!uri) {
    console.error('Error: MONGO_URI is not set in .env');
    process.exit(1);
  }

  ensureReliableDnsForAtlas(uri);

  try {
    const conn = await mongoose.connect(uri, {
      // Avoid IPv6 DNS quirks on some Windows networks
      family: 4,
      serverSelectionTimeoutMS: 30000,
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
