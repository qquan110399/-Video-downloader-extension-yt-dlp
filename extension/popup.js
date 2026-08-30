const browserAPI = typeof browser !== "undefined" ? browser : chrome;
const nativeHostName = "ytdlp_native_host";

document.addEventListener("DOMContentLoaded", async () => {
  const videoUrlInput = document.getElementById("videoUrl");
  const qualitySelect = document.getElementById("quality");
  const downloadFolderInput = document.getElementById("downloadFolder");
  const browseBtn = document.getElementById("browseBtn");
  const downloadBtn = document.getElementById("downloadBtn");
  const hostStatus = document.getElementById("hostStatus");
  
  const progressContainer = document.getElementById("progressContainer");
  const statusText = document.getElementById("statusText");
  const percentText = document.getElementById("percentText");
  const progressBar = document.getElementById("progressBar");
  const speedText = document.getElementById("speedText");
  const etaText = document.getElementById("etaText");
  const logArea = document.getElementById("logArea");

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

  // Native host connection
  let port = null;

  function connectNativeHost() {
    try {
      port = browserAPI.runtime.connectNative(nativeHostName);
      
      port.onMessage.addListener((msg) => {
        handleNativeMessage(msg);
      });

      port.onDisconnect.addListener((p) => {
        if (browserAPI.runtime && browserAPI.runtime.lastError) {
          hostStatus.textContent = "Offline (Host not ready)";
          hostStatus.className = "badge offline";
          logMessage("Connection Error: " + browserAPI.runtime.lastError.message);
        } else {
          hostStatus.textContent = "Disconnected";
          hostStatus.className = "badge offline";
        }
      });

      // Ping test
      port.postMessage({ action: "ping" });
    } catch (e) {
      hostStatus.textContent = "Offline";
      hostStatus.className = "badge offline";
    }
  }

  function handleNativeMessage(msg) {
    if (msg.status === "pong") {
      hostStatus.textContent = "Ready (yt-dlp v" + (msg.version || "ok") + ")";
      hostStatus.className = "badge online";
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
    logArea.classList.remove("hidden");
    logArea.textContent += text + "\n";
    logArea.scrollTop = logArea.scrollHeight;
  }

  // Browse folder button
  browseBtn.addEventListener("click", () => {
    browseBtn.disabled = true;
    if (!port) {
      connectNativeHost();
    }
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

    downloadBtn.disabled = true;
    progressContainer.classList.remove("hidden");
    progressBar.style.width = "0%";
    percentText.textContent = "0%";
    statusText.textContent = "Sending download task...";
    logArea.textContent = "";

    if (!port) {
      connectNativeHost();
    }

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

  // Connect on load
  connectNativeHost();
});
