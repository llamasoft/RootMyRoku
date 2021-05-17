Sub Main()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("StatusScreen")
    screen.show()

    m.status = scene.FindNode("statusLabel")
    m.status.text = "If you're seeing this, the NFS mount failed or the exploit was patched. :("
    Stop

    While True
        event = wait(30000, m.port)
        event_type = type(event)
        If event_type = "roSGScreenEvent" Then
            ' When the screen is closed, shut everything down.
            If event.isScreenClosed() Then
                Return
            End If
        End If
    End While
End Sub
