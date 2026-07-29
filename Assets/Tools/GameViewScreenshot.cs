using System;
using System.IO;
using UnityEngine;
using UnityEngine.InputSystem;

public class GameViewScreenshot : MonoBehaviour
{
    [Min(1)]
    [SerializeField] private int resolutionScale = 1;

    private void Update()
    {
        if (Keyboard.current != null && Keyboard.current.f12Key.wasPressedThisFrame)
        {
            Capture();
        }
    }

    [ContextMenu("Capture Game View")]
    public void Capture()
    {
        if (!Application.isPlaying)
        {
            Debug.LogWarning("Enter Play mode before capturing the Game view.");
            return;
        }

        string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Screenshots"));
        Directory.CreateDirectory(folder);

        string fileName = $"GameView_{DateTime.Now:yyyy-MM-dd_HH-mm-ss-fff}.png";
        string path = Path.Combine(folder, fileName);

        ScreenCapture.CaptureScreenshot(path, resolutionScale);
        Debug.Log($"Game view screenshot saved to: {path}");
    }
}
