const browserAPI = typeof browser !== "undefined" ? browser : chrome;
const nativeHostName = "ytdlp_native_host";

document.addEventListener("DOMContentLoaded", async () => {
  const videoUrlInput = document.getElementById("videoUrl");
  const qualitySelect = document.getElementById("quality");
  const downloadFolderInput = document.getElementById("downloadFolder");
  const browseBtn = document.getElementById("browseBtn");
  const downloadBtn = document.getElementById("downloadBtn");
  const hostStatus = document.getElementById("hostStatus");
  const reconnectBtn = document.getElementById("reconnectBtn");
  const offlineNotice = document.getElementById("offlineNotice");
  const alertRetryBtn = document.getElementById("alertRetryBtn");
  
  const progressContainer = document.getElementById("progressContainer");
  const statusText = document.getElementById("statusText");
  const percentText = document.getElementById("percentText");
  const progressBar = document.getElementById("progressBar");
  const speedText = document.getElementById("speedText");
  const etaText = document.getElementById("etaText");
  const logArea = document.getElementById("logArea");

  let port = null;
  let isConnected = false;

  // Load saved download folder from local storage
  try {
    const savedFolder = localStorage.getItem("ytdlp_download_folder");
    if (savedFolder) {
      downloadFolderInput.value = savedFolder;
    }
  } catch (e) {
    console.log("Could not load saved folder setting", e);
  }

  // Save folder preference whenever manually modified
  downloadFolderInput.addEventListener("change", () => {
    try {
      localStorage.setItem("ytdlp_download_folder", downloadFolderInput.value.trim());
    } catch (e) {}
  });

  // Get active tab URL automatically
  try {
    const tabs = await browserAPI.tabs.query({ active: true, currentWindow: true });
    if (tabs && tabs[0] && tabs[0].url) {
      if (tabs[0].url.startsWith("http://") || tabs[0].url.startsWith("https://")) {
        videoUrlInput.value = tabs[0].url;
      }
    }
  } catch (err) {
    console.log("Could not fetch tab URL", err);
  }

  function setHostOffline(reason) {
    isConnected = false;
    port = null;
    hostStatus.textContent = "Offline (Host not ready)";
    hostStatus.className = "badge offline";
    if (reconnectBtn) reconnectBtn.classList.remove("hidden");
    if (offlineNotice) offlineNotice.classList.remove("hidden");
    if (reason) {
      logMessage("Native Host Status: " + reason);
    }
  }

  function setHostOnline(version) {
    isConnected = true;
    hostStatus.textContent = "Ready (yt-dlp v" + (version || "ok") + ")";
    hostStatus.className = "badge online";
    if (reconnectBtn) reconnectBtn.classList.remove("hidden");
    if (offlineNotice) offlineNotice.classList.add("hidden");
  }

  function connectNativeHost() {
    if (port) {
      try { port.disconnect(); } catch (e) {}
      port = null;
    }

    hostStatus.textContent = "Connecting...";
    hostStatus.className = "badge";

    try {
      if (!browserAPI.runtime || !browserAPI.runtime.connectNative) {
        setHostOffline("Native messaging API not supported in this context.");
        return null;
      }

      port = browserAPI.runtime.connectNative(nativeHostName);

      if (!port) {
        setHostOffline("Could not initiate native port connection.");
        return null;
      }

      port.onMessage.addListener((msg) => {
        handleNativeMessage(msg);
      });

      port.onDisconnect.addListener((p) => {
        let errMsg = "Host disconnected.";
        if (browserAPI.runtime && browserAPI.runtime.lastError) {
          errMsg = browserAPI.runtime.lastError.message;
        }
        setHostOffline(errMsg);
      });

      // Send ping test
      try {
        port.postMessage({ action: "ping" });
      } catch (postErr) {
        setHostOffline(postErr.message);
        return null;
      }

      return port;
    } catch (e) {
      setHostOffline(e.message);
      return null;
    }
  }

  function handleNativeMessage(msg) {
    if (!msg) return;

    if (msg.status === "pong") {
      setHostOnline(msg.version);
    } else if (msg.status === "folder_selected") {
      if (msg.path) {
        downloadFolderInput.value = msg.path;
        try {
          localStorage.setItem("ytdlp_download_folder", msg.path);
        } catch (e) {}
        logMessage("Download folder set to: " + msg.path);
      }
      browseBtn.disabled = false;
    } else if (msg.status === "folder_selection_cancelled") {
      browseBtn.disabled = false;
    } else if (msg.status === "downloading") {
      progressContainer.classList.remove("hidden");
      const percent = msg.percent || 0;
      progressBar.style.width = percent + "%";
      percentText.textContent = Math.round(percent) + "%";
      statusText.textContent = msg.text || "Downloading...";
      speedText.textContent = msg.speed ? msg.speed : "-- MiB/s";
      etaText.textContent = msg.eta ? "ETA: " + msg.eta : "ETA: --";
    } else if (msg.status === "finished") {
      progressContainer.classList.remove("hidden");
      progressBar.style.width = "100%";
      percentText.textContent = "100%";
      statusText.textContent = "Download complete!";
      downloadBtn.disabled = false;
      logMessage("Saved to: " + (msg.filename || "Downloads folder"));
    } else if (msg.status === "error") {
      progressContainer.classList.remove("hidden");
      statusText.textContent = "Download failed!";
      downloadBtn.disabled = false;
      logMessage("Error: " + msg.error);
    } else if (msg.log) {
      logMessage(msg.log);
    }
  }

  function logMessage(text) {
    if (!logArea) return;
    logArea.classList.remove("hidden");
    logArea.textContent += text + "\n";
    logArea.scrollTop = logArea.scrollHeight;
  }

  // Reconnect buttons
  if (reconnectBtn) {
    reconnectBtn.addEventListener("click", () => {
      logMessage("Attempting to reconnect to native host...");
      connectNativeHost();
    });
  }

  if (alertRetryBtn) {
    alertRetryBtn.addEventListener("click", () => {
      logMessage("Attempting to reconnect to native host...");
      connectNativeHost();
    });
  }

  // Browse folder button
  browseBtn.addEventListener("click", () => {
    if (!port || !isConnected) {
      connectNativeHost();
    }

    if (!port) {
      logMessage("Cannot open folder picker: Native Host is offline. Please run install_all.bat.");
      return;
    }

    browseBtn.disabled = true;
    try {
      port.postMessage({
        action: "select_folder",
        initial_dir: downloadFolderInput.value.trim() || ""
      });
    } catch (e) {
      browseBtn.disabled = false;
      logMessage("Error opening folder picker: " + e.message);
    }
  });

  // Start download button
  downloadBtn.addEventListener("click", () => {
    const url = videoUrlInput.value.trim();
    const quality = qualitySelect.value;
    const downloadDir = downloadFolderInput.value.trim();

    if (!url) {
      alert("Please enter a valid video URL!");
      return;
    }

    if (!port || !isConnected) {
      connectNativeHost();
    }

    if (!port) {
      progressContainer.classList.remove("hidden");
      statusText.textContent = "Host is Offline!";
      downloadBtn.disabled = false;
      logMessage("Error: Native host is offline. Make sure you ran 'install_all.bat' (or 'install_host.bat') and Python is installed.");
      return;
    }

    downloadBtn.disabled = true;
    progressContainer.classList.remove("hidden");
    progressBar.style.width = "0%";
    percentText.textContent = "0%";
    statusText.textContent = "Sending download task...";
    logArea.textContent = "";

    try {
      port.postMessage({
        action: "download",
        url: url,
        quality: quality,
        download_dir: downloadDir
      });
    } catch (e) {
      statusText.textContent = "Connection Error!";
      downloadBtn.disabled = false;
      logMessage("Failed to send command: " + e.message);
    }
  });

  // Connect immediately on popup open
  connectNativeHost();
});
