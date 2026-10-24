# Intel Wi-Fi first-connect disconnect fix

Fix for Windows laptops with Intel Wi-Fi that disconnect about 30 seconds after the **first** connection to a network. The cause is the **Intel Connectivity Network Service**.

## Is this your problem?

You probably have this problem if **all** of these are true:

- You use Windows 10 or 11 on a laptop with an **Intel Wi-Fi card**. It was confirmed on an Intel Wi-Fi 7 BE201 with driver 24.70.0.3.
- The **first** time you connect to a Wi-Fi network, it connects and then **drops by itself about 30 seconds later**.
- When you **reconnect**, it works and stays connected.
- **Other devices** (phones, other laptops) on the same Wi-Fi network have no problems.
- Before it drops, Windows may show "No internet" even though the network is working.

## Confirm it before applying the fix

1. Connect to a Wi-Fi network and wait for it to drop. Note the time.
2. Open **Event Viewer**. Press `Win + R`, type `eventvwr.msc`, and press Enter.
3. Go to **Windows Logs → System**.
4. Click **Filter Current Log...** in the right panel.
   - Event sources: **WLAN-AutoConfig**
   - Event IDs: **4003**
5. Look for an entry around **30 seconds after you connected** with text like:

   > WLAN AutoConfig detected limited connectivity, attempting automatic recovery. Recovery Type: 4

If you see it, this fix applies to you. You can also run the script and choose **option 1 (Check status)**. It shows whether the service is installed and running, and counts these events from the last 30 days.

## How to use

### Apply the fix

1. Download the repository with **Code → Download ZIP**, then extract it. This keeps the script's Windows (CRLF) line endings. You can also use `git clone`. "Download raw file" gives Unix line endings, so avoid it.
2. Right-click the file and choose **Run as administrator**. If you just double-click it, it asks for administrator rights itself.
3. Choose **2. Apply fix**.
4. Disconnect from your Wi-Fi and connect again to test it.

The script stops the `Intel Connectivity Network Service` and sets its startup type to **Disabled**. It does nothing else.

### Undo the fix

Run the script again and choose **3. Undo fix**. This sets the service back to **Automatic** and starts it.

### What the script does NOT do

- It does not edit the registry.
- It does not change, update, or remove drivers.
- It does not change Wi-Fi profiles or network settings.
- It does not read or export Wi-Fi passwords.

If the service is not installed, the script tells you and makes no changes.

## Root cause

- The **Intel Connectivity Network Service** is part of Intel Connectivity Performance Suite, which installs with the Intel Wi-Fi driver. About **16 seconds** after you connect, it interferes with the connection. In `Applications and Services Logs → Microsoft → Windows → WLAN-AutoConfig → Operational`, you see "Wireless security stopped" and "Wireless security started" (events 11004 and 11010) without a disconnect.
- Because of this, the Windows internet check (NCSI) never passes. It only sees **Local** connectivity.
- About **32 seconds** after you connect, WLAN AutoConfig logs System event **4003** ("detected limited connectivity, attempting automatic recovery", Recovery Type 4). It then **resets the Wi-Fi driver**: the Intel driver (source `Netwaw*` / `Netwtw*`) logs event 8000 "Wi-Fi Driver Miniport Halt", and the WLAN log shows event 8003 "The network is disconnected by the driver".
- Windows only does this recovery **once**, which is why the second connection is stable.

After the service was disabled, the internet check passed right away (NCSI `ActiveHttpProbeSucceeded`). There were no events at 16 seconds, no 4003 events, and no disconnects.

## What did NOT fix it

These were tried and made no difference:

- Changing the router or hotspot security from WPA2/WPA3 to **WPA2 only**
- Changing the adapter's **802.11n/ac/ax/be Wireless Mode** from 802.11be to **802.11ax**
- **Updating the Wi-Fi driver** (it was already the latest version)

## Notes

- **Updates can turn the service back on.** An Intel driver update or Intel software update may re-enable the service. If the problem comes back, run the script again and choose option 2.
- **Turning the service off disables Intel Connectivity Performance Suite features.** Normal Wi-Fi keeps working.

## Disclaimer

This fix was verified on **one** machine. Use it at your own risk. This project has no affiliation with Intel or Microsoft. All product names are trademarks of their respective owners.

## License

[MIT](LICENSE)
