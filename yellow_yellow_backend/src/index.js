const express = require('express');
const { PrismaClient } = require('@prisma/client');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http'); 
const { Server } = require('socket.io');

dotenv.config();
const app = express(); 
const prisma = new PrismaClient();

// Create the HTTP server wrapper around the Express app instance
const server = http.createServer(app);

// Initialize Socket.io on top of the HTTP wrapper server
const io = new Server(server, {
  cors: {
    origin: "*", 
    methods: ["GET", "POST", "PATCH"]
  }
});

app.use(cors());
app.use(express.json());

app.get('/users', async (req, res) => {
  try {
    const allUsers = await prisma.user.findMany();
    res.json(allUsers);
  } catch (error) {
    console.error("DETAILED ERROR:", error); 
    res.status(400).json({ error: 'Database error occurred.' });
  }
});

app.post('/register', async (req, res) => {
  console.log('Incoming request body:', req.body); 

  const { phoneNumber, userType } = req.body;

  try {
    const newUser = await prisma.user.create({
      data: {
        phoneNumber: phoneNumber,
        userType: userType,
      },
    });
    console.log('User created successfully:', newUser.id);
    res.status(201).json(newUser);
  } catch (error) {
    console.error('Prisma Error:', error.message); 
    res.status(400).json({ error: 'User already exists or data is invalid.' });
  }
});

app.post('/login', async (req, res) => {
  const { phoneNumber } = req.body;
  console.log('Login attempt for:', phoneNumber);
  try {
    const user = await prisma.user.findUnique({
      where: { phoneNumber: phoneNumber },
    });

    if (user) {
      console.log('User logged in:', user.id);
      res.status(200).json(user);
    } else {
      console.log('Login failed: User not found');
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    console.log('Server Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

app.patch('/users/location', async (req, res) => {
  const { phoneNumber, latitude, longitude } = req.body;
  try {
    await prisma.user.update({
      where: { phoneNumber: phoneNumber },
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

// UPGRADED TRIP REQUEST WITH WEBSOCKET BROADCAST
app.post('/trips/request', async (req, res) => {
  const { passengerPhone, pickupLat, pickupLng, destLat, destLng, price } = req.body;

  try {
    const passenger = await prisma.user.findUnique({
      where: { phoneNumber: passengerPhone }
    });

    if (!passenger) {
      return res.status(404).json({ error: 'Passenger not found' });
    }

    const newTrip = await prisma.trip.create({
      data: {
        passengerId: passenger.id,
        pickupLatitude: parseFloat(pickupLat),
        pickupLongitude: parseFloat(pickupLng),
        destinationLatitude: parseFloat(destLat),
        destinationLongitude: parseFloat(destLng),
        price: parseFloat(price),
        status: 'PENDING'
      }
    });

    console.log(`[Database] Ride requested by ${passengerPhone}. Trip ID: ${newTrip.id}`);

    // EMIT EVENT: Broadcast the live trip request parameters to all connected sockets
    io.emit('new_trip_requested', {
      tripId: newTrip.id,
      passengerPhone: passengerPhone,
      pickup: { lat: parseFloat(pickupLat), lng: parseFloat(pickupLng) },
      destination: { lat: parseFloat(destLat), lng: parseFloat(destLng) },
      price: parseFloat(price)
    });
    console.log(`[WebSocket] Broadcasted trip ${newTrip.id} live to drivers.`);

    res.status(201).json(newTrip);
  } catch (error) {
    console.error('Error creating trip:', error.message);
    res.status(500).json({ error: error.message });
  }
});

app.patch('/trips/accept', async (req, res) => {
  const { tripId, driverPhone } = req.body;

  try {
    // 1. Verify the driver exists in the system
    const driver = await prisma.user.findUnique({
      where: { phoneNumber: driverPhone }
    });

    if (!driver || driver.userType !== 'DRIVER') {
      return res.status(404).json({ error: 'Valid driver profile not found.' });
    }

    // 2. Update trip state and assign the driverId
    const updatedTrip = await prisma.trip.update({
      where: { id: tripId },
      data: {
        driverId: driver.id,
        status: 'ACCEPTED'
      }
    });

    console.log(`[Database] Trip ${tripId} accepted by driver ${driverPhone}`);

    // 3. Notify the passenger via WebSocket that their ride has been accepted
    io.emit('trip_status_updated', {
      tripId: updatedTrip.id,
      status: 'ACCEPTED',
      driverPhone: driverPhone,
      driverLocation: { lat: driver.latitude, lng: driver.longitude }
    });

    res.status(200).json(updatedTrip);
  } catch (error) {
    console.error('Error accepting trip:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// SOCKET CONNECTION HANDLER
io.on('connection', (socket) => {
  console.log(`[WebSocket] Client connected. Socket ID: ${socket.id}`);

  socket.on('disconnect', () => {
    console.log(`[WebSocket] Client disconnected. Socket ID: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 5005;

// CRUCIAL: Listen via the HTTP wrapper server instead of app.listen
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is live at http://0.0.0.0:${PORT}`);
});