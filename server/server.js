const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Структуры данных
const rooms = new Map();
const users = new Map();

// Класс комнаты
class Room {
  constructor(id, name, createdBy) {
    this.id = id;
    this.name = name;
    this.createdBy = createdBy;
    this.players = [];
    this.spectators = [];
    this.gameState = {
      board: Array(15).fill().map(() => Array(15).fill(0)),
      currentPlayer: 1,
      gameStarted: false,
      gameOver: false,
      winner: null,
      lastMove: null
    };
    this.chatMessages = [];
    this.createdAt = new Date();
  }

  addPlayer(socket, username, playerId) {
    if (this.players.length >= 2) {
      return { success: false, role: 'spectator' };
    }

    const player = {
      id: playerId,
      socketId: socket.id,
      username: username,
      playerNumber: this.players.length + 1
    };

    this.players.push(player);
    socket.join(this.id);
    
    return { success: true, role: 'player', playerNumber: player.playerNumber };
  }

  addSpectator(socket, username, playerId) {
    const spectator = {
      id: playerId,
      socketId: socket.id,
      username: username
    };

    this.spectators.push(spectator);
    socket.join(this.id);
    
    return { success: true, role: 'spectator' };
  }

  removeUser(socketId) {
    this.players = this.players.filter(p => p.socketId !== socketId);
    this.spectators = this.spectators.filter(s => s.socketId !== socketId);
    
    if (this.gameState.gameStarted && !this.gameState.gameOver) {
      const remainingPlayer = this.players[0];
      if (remainingPlayer) {
        this.gameState.gameOver = true;
        this.gameState.winner = remainingPlayer.playerNumber;
      }
    }
    
    this.broadcastRoomUpdate();
  }

  makeMove(playerId, row, col) {
    const player = this.players.find(p => p.id === playerId);
    if (!player || 
        !this.gameState.gameStarted || 
        this.gameState.gameOver || 
        this.gameState.currentPlayer !== player.playerNumber) {
      return { success: false, message: 'Invalid move' };
    }

    if (row < 0 || row >= 15 || col < 0 || col >= 15 || this.gameState.board[row][col] !== 0) {
      return { success: false, message: 'Invalid position' };
    }

    this.gameState.board[row][col] = player.playerNumber === 1 ? 1 : -1;
    this.gameState.lastMove = { 
      row, 
      col, 
      player: player.playerNumber,
      playerName: player.username 
    };
    
    if (this.checkWin(row, col, player.playerNumber === 1 ? 1 : -1)) {
      this.gameState.gameOver = true;
      this.gameState.winner = player.playerNumber;
    } else if (this.checkDraw()) {
      this.gameState.gameOver = true;
      this.gameState.winner = 0;
    } else {
      this.gameState.currentPlayer = this.gameState.currentPlayer === 1 ? 2 : 1;
    }

    this.broadcastGameState();
    return { success: true };
  }

  checkWin(row, col, player) {
    const directions = [
      [0, 1], [1, 0], [1, 1], [1, -1]
    ];

    for (const [dx, dy] of directions) {
      let count = 1;

      for (let i = 1; i <= 4; i++) {
        const newRow = row + dx * i;
        const newCol = col + dy * i;
        if (newRow >= 0 && newRow < 15 && newCol >= 0 && newCol < 15 && 
            this.gameState.board[newRow][newCol] === player) {
          count++;
        } else break;
      }

      for (let i = 1; i <= 4; i++) {
        const newRow = row - dx * i;
        const newCol = col - dy * i;
        if (newRow >= 0 && newRow < 15 && newCol >= 0 && newCol < 15 && 
            this.gameState.board[newRow][newCol] === player) {
          count++;
        } else break;
      }

      if (count >= 5) return true;
    }
    return false;
  }

  checkDraw() {
    return this.gameState.board.flat().every(cell => cell !== 0);
  }

  startGame() {
    if (this.players.length === 2 && !this.gameState.gameStarted) {
      this.gameState.gameStarted = true;
      this.gameState.currentPlayer = 1;
      this.gameState.board = Array(15).fill().map(() => Array(15).fill(0));
      this.gameState.gameOver = false;
      this.gameState.winner = null;
      this.gameState.lastMove = null;
      
      this.broadcastGameState();
      return true;
    }
    return false;
  }

  resetGame() {
    this.gameState.board = Array(15).fill().map(() => Array(15).fill(0));
    this.gameState.currentPlayer = 1;
    this.gameState.gameOver = false;
    this.gameState.winner = null;
    this.gameState.lastMove = null;
    this.gameState.gameStarted = true;
    
    this.broadcastGameState();
  }

  addChatMessage(username, message, playerId) {
    const chatMessage = {
      id: Date.now().toString(),
      playerId,
      username,
      message,
      timestamp: new Date().toISOString()
    };
    
    this.chatMessages.push(chatMessage);
    if (this.chatMessages.length > 100) {
      this.chatMessages.shift();
    }
    
    io.to(this.id).emit('chat_message', chatMessage);
  }

  broadcastRoomUpdate() {
    io.to(this.id).emit('room_update', this.getRoomInfo());
  }

  broadcastGameState() {
    io.to(this.id).emit('game_state', this.gameState);
  }

  getRoomInfo() {
    return {
      id: this.id,
      name: this.name,
      createdBy: this.createdBy,
      players: this.players.map(p => ({
        id: p.id,
        username: p.username,
        playerNumber: p.playerNumber
      })),
      spectators: this.spectators.map(s => ({
        id: s.id,
        username: s.username
      })),
      gameState: this.gameState,
      playerCount: this.players.length,
      spectatorCount: this.spectators.length,
      createdAt: this.createdAt
    };
  }
}

// Вспомогательные функции
function generateId() {
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

function generateRoomId() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// REST API Routes
app.get('/api/rooms', (req, res) => {
  const roomList = Array.from(rooms.values()).map(room => ({
    id: room.id,
    name: room.name,
    createdBy: room.createdBy,
    playerCount: room.players.length,
    spectatorCount: room.spectators.length,
    gameStarted: room.gameState.gameStarted,
    createdAt: room.createdAt
  }));
  
  res.json({ success: true, rooms: roomList });
});

app.get('/api/stats', (req, res) => {
  res.json({
    success: true,
    stats: {
      totalRooms: rooms.size,
      totalUsers: users.size,
      onlinePlayers: Array.from(users.values()).filter(u => u.roomId).length
    }
  });
});

// Socket.io обработчики
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('create_room', (data) => {
    const { roomName, username } = data;
    const roomId = generateRoomId();
    const playerId = generateId();
    
    const room = new Room(roomId, roomName, username);
    rooms.set(roomId, room);
    
    users.set(socket.id, { 
      id: playerId, 
      username, 
      roomId,
      socketId: socket.id 
    });

    const joinResult = room.addPlayer(socket, username, playerId);
    
    socket.emit('room_created', {
      success: true,
      roomId,
      playerId,
      roomInfo: room.getRoomInfo(),
      role: joinResult.role,
      playerNumber: joinResult.playerNumber
    });

    room.broadcastRoomUpdate();
  });

  socket.on('join_room', (data) => {
    const { roomId, username } = data;
    const playerId = generateId();
    
    if (!rooms.has(roomId)) {
      socket.emit('error', { message: 'Room not found' });
      return;
    }

    const room = rooms.get(roomId);
    users.set(socket.id, { 
      id: playerId, 
      username, 
      roomId,
      socketId: socket.id 
    });

    let joinResult = room.addPlayer(socket, username, playerId);
    
    if (!joinResult.success) {
      joinResult = room.addSpectator(socket, username, playerId);
      socket.emit('joined_room', {
        success: true,
        roomId,
        playerId,
        roomInfo: room.getRoomInfo(),
        role: joinResult.role
      });
    } else {
      socket.emit('joined_room', {
        success: true,
        roomId,
        playerId,
        roomInfo: room.getRoomInfo(),
        role: joinResult.role,
        playerNumber: joinResult.playerNumber
      });
    }

    socket.emit('chat_history', room.chatMessages);
    room.broadcastRoomUpdate();
  });

  socket.on('make_move', (data) => {
    const { roomId, playerId, row, col } = data;
    const user = users.get(socket.id);
    
    if (!user || user.roomId !== roomId) {
      socket.emit('move_result', { success: false, message: 'Not in room' });
      return;
    }
    
    const room = rooms.get(roomId);
    if (room) {
      const result = room.makeMove(playerId, row, col);
      socket.emit('move_result', result);
    }
  });

  socket.on('start_game', (data) => {
    const { roomId } = data;
    const user = users.get(socket.id);
    
    if (!user || user.roomId !== roomId) return;
    
    const room = rooms.get(roomId);
    if (room && room.players.some(p => p.socketId === socket.id)) {
      const started = room.startGame();
      socket.emit('game_started', { success: started });
    }
  });

  socket.on('reset_game', (data) => {
    const { roomId } = data;
    const user = users.get(socket.id);
    
    if (!user || user.roomId !== roomId) return;
    
    const room = rooms.get(roomId);
    if (room && room.players.some(p => p.socketId === socket.id)) {
      room.resetGame();
      socket.emit('game_reset', { success: true });
    }
  });

  socket.on('send_message', (data) => {
    const { roomId, message } = data;
    const user = users.get(socket.id);
    
    if (!user || user.roomId !== roomId) return;
    
    const room = rooms.get(roomId);
    if (room) {
      room.addChatMessage(user.username, message, user.id);
    }
  });

  socket.on('leave_room', (data) => {
    const { roomId } = data;
    const user = users.get(socket.id);
    
    if (!user || !user.roomId) return;
    
    const room = rooms.get(user.roomId);
    if (room) {
      room.removeUser(socket.id);
      socket.leave(user.roomId);
      
      if (room.players.length === 0 && room.spectators.length === 0) {
        rooms.delete(room.id);
      }
      
      room.broadcastRoomUpdate();
    }
    
    users.delete(socket.id);
    socket.emit('left_room', { success: true });
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    
    const user = users.get(socket.id);
    if (user && user.roomId) {
      const room = rooms.get(user.roomId);
      if (room) {
        room.removeUser(socket.id);
        
        if (room.players.length === 0 && room.spectators.length === 0) {
          rooms.delete(room.id);
        } else {
          room.broadcastRoomUpdate();
        }
      }
    }
    
    users.delete(socket.id);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});