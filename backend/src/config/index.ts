import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  supabase: {
    url: process.env.SUPABASE_URL || '',
    serviceKey: process.env.SUPABASE_SERVICE_KEY || '',
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-in-production',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },

  admin: {
    email: process.env.ADMIN_EMAIL || 'admin@zero.app',
    password: process.env.ADMIN_PASSWORD || 'admin123456',
  },

  payment: {
    webhookSecret: process.env.PAYMENT_WEBHOOK_SECRET || '',
  },
};
