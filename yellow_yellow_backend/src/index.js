const express = require('express');
const { PrismaClient } = require('@prisma/client');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();
const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json());

app.get('/users', async (req, res) => {
  try {
    const allUsers = await prisma.user.findMany();
    res.json(allUsers);
  } catch (error) {
    res.status(400).json({ error: 'Database error' });
  }
});

app.post('/register', async (req, res) => {
  const { phoneNumber, userType } = req.body;
  try {
    const newUser = await prisma.user.create({
      data: { phoneNumber, userType },
    });
    res.status(201).json(newUser);
  } catch (error) {
    res.status(400).json({ error: 'User already exists' });
  }
});

app.post('/login', async (req, res) => {
  const { phoneNumber } = req.body;
  try {
    const user = await prisma.user.findUnique({ where: { phoneNumber } });
    if (user) res.status(200).json(user);
    else res.status(404).json({ error: 'User not found' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.patch('/users/location', async (req, res) => {
  const { phoneNumber, latitude, longitude } = req.body;
  try {
    await prisma.user.update({
      where: { phoneNumber },
      data: {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
      },
    });
    res.status(200).json({ message: 'Location updated' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// THIS WAS THE MISSING PART
app.get('/users/drivers', async (req, res) => {
  try {
    const drivers = await prisma.user.findMany({
      where: {
        userType: 'DRIVER',
        latitude: { not: null },
        longitude: { not: null },
      },
      select: {
        id: true,
        phoneNumber: true,
        latitude: true,
        longitude: true,
      },
    });
    res.status(200).json(drivers);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = 5005;
app.listen(PORT, '0.0.0.0', () => {
  console.log('--- SERVER RESTARTED WITH DRIVER ROUTE ---');
});
