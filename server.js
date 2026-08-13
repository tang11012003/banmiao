const http = require('http');
const httpProxy = require('http-proxy');
const express = require('express');
const path = require('path');

const PORT = 8081;
const BACKEND = 'http://localhost:8080';

const proxy = httpProxy.createProxyServer({ target: BACKEND });
const app = express();

const webDir = path.join(__dirname, 'frontend', 'build', 'web');

// Serve static files first
app.use(express.static(webDir));

// Create HTTP server manually to intercept /api before express
const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api')) {
    proxy.web(req, res, { target: BACKEND }, (err) => {
      res.writeHead(502);
      res.end('Proxy error: ' + err.message);
    });
  } else {
    app(req, res);
  }
});

// SPA fallback - serve index.html for non-static routes
app.use((req, res) => {
  res.sendFile(path.join(webDir, 'index.html'));
});

server.listen(PORT, () => {
  console.log(`Reverse proxy running on http://localhost:${PORT}`);
  console.log(`  -> Static files: ${webDir}`);
  console.log(`  -> API proxy: ${BACKEND}`);
});
