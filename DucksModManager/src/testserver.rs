//! A tiny HTTP server for the tests.
//!
//! The updaters talk to `ureq`, so testing them end to end needs something to talk to. This serves
//! a fixed set of routes out of memory on `127.0.0.1`, which lets the tests point a release folder
//! or a pack archive at a temp directory and watch what the real download code does with it.

use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::{self, JoinHandle};
use std::time::Duration;

pub struct TestServer {
    /// `http://127.0.0.1:<port>`, with no trailing slash.
    base: String,
    stop: Arc<AtomicBool>,
    handle: Option<JoinHandle<()>>,
}

impl TestServer {
    /// Serves `routes` — `("/version.txt", b"1.2.3".to_vec())` — until the value is dropped.
    pub fn serve<R: Into<String>>(routes: Vec<(R, Vec<u8>)>) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind the test server");
        listener
            .set_nonblocking(true)
            .expect("make the test server non-blocking");
        let address = listener.local_addr().expect("learn the test server's port");

        let routes: HashMap<String, Vec<u8>> = routes
            .into_iter()
            .map(|(route, body)| (route.into(), body))
            .collect();
        let stop = Arc::new(AtomicBool::new(false));
        let stopping = Arc::clone(&stop);

        let handle = thread::spawn(move || {
            while !stopping.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((mut stream, _)) => respond(&mut stream, &routes),
                    Err(err) if err.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(Duration::from_millis(5));
                    }
                    Err(_) => break,
                }
            }
        });

        Self {
            base: format!("http://{address}"),
            stop,
            handle: Some(handle),
        }
    }

    pub fn base(&self) -> &str {
        &self.base
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
    }
}

/// Answers one request: the route's bytes, or a 404. Only GET is used, and the tests always close
/// the connection, so the request line is all that has to be read.
fn respond(stream: &mut std::net::TcpStream, routes: &HashMap<String, Vec<u8>>) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
    let _ = stream.set_write_timeout(Some(Duration::from_secs(2)));

    let mut buffer = [0u8; 4096];
    let read = stream.read(&mut buffer).unwrap_or(0);
    let request = String::from_utf8_lossy(&buffer[..read]);
    let route = request.split_whitespace().nth(1).unwrap_or("/");

    let response = match routes.get(route) {
        Some(body) => {
            let mut response = format!(
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                body.len()
            )
            .into_bytes();
            response.extend_from_slice(body);
            response
        }
        None => b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            .to_vec(),
    };

    let _ = stream.write_all(&response);
    let _ = stream.flush();
}
