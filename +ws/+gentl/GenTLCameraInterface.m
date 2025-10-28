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
                fprintf('   Establishing connection to camera...\n');
                fopen(self.cameraServer);
                fprintf('   Connection established!\n');
            else
                fprintf('   Connection already established...\n');
            end
        end

        function startCapture(self, pipette, sweep)
            fprintf(['   Starting capture for p' num2str(pipette) '_' num2str(sweep, '%04.f') '\n'])
            fwrite(self.cameraServer, [1 pipette sweep])
        end
        
        function stopCapture(self)
            fwrite(self.cameraServer, [2 0 0])
        end
        
        function disconnect(self)
            if self.cameraServer.BytesToOutput == 0
                fwrite(self.cameraServer, [3 0 0])
                fclose(self.cameraServer);
            else
                pause(0.1);
                fwrite(self.cameraServer, [3 0 0])
                fclose(self.cameraServer);
            end
        end
        
    end
end