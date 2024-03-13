classdef GenTLCameraInterface < handle
    properties (SetAccess=protected)
        address_ = ''
        port_ = []
        cameraServer = []
    end
    
    methods
        function self = GenTLCameraInterface(address, port)
            self.address_ = address;
            self.port_ = port;
        end
        
        function connect(self)
            self.cameraServer = tcpip(self.address_, self.port_, 'NetworkRole', 'server');
            if strcmp(self.cameraServer.Status, 'closed')
                fprintf('   Establishing connection to camera');
                fopen(self.cameraServer);
                fprintf('   Connection established');
            else
                fprintf('   Connection already established');
            end
        end
                
        function disconnect(self)
            if self.cameraServer.BytesToOutput == 0
                fwrite(self.cameraServer, 3, 'int8')
                fclose(self.cameraServer);
            else
                pause(0.1);
                fwrite(self.cameraServer, 3, 'int8')
                fclose(self.cameraServer);
            end
        end
        
        function startCapture(self)
            fwrite(self.cameraServer, 1, 'int8')
        end
        
        function stopCapture(self)
            fwrite(self.cameraServer, 2, 'int8')
        end
        
        
    end
end