import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { seedDatabase } from './seed';

dotenv.config();

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'streaming_db',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: true,
});

AppDataSource.initialize()
  .then(async () => {
    console.log('📦 Connected to database, running seed...');
    await seedDatabase(AppDataSource);
    await AppDataSource.destroy();
    process.exit(0);
  })
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  });
