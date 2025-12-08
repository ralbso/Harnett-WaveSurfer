classdef CameraAcquisition < handle
    properties (Constant=true)
        frameRate = 62
        exposureTime = 15000
        roiPosition = [0 0 592 592]
        compressionQuality = 100
        LineIndicator = '  '
        codec = 'MPEG-4'
        ext = '.mp4'
        address = '169.254.99.158'
        port = 4545
        bytesAvailableCnt = 3
        
        cameraTTLPort = 'COM5'
        baudRate = 128000;
    end
    
    properties (Constant=false)
        fallbackSweep = 101
    end
    
    properties
        rootpath
        client
        camera
        cameraSerial
    end
    
    methods
        function self = CameraAcquisition(rootpath)
            self.rootpath = rootpath;

            self.client = tcpip(self.address, self.port, 'NetworkRole', 'client');
            self.client.Timeout = Inf;
            self.client.BytesAvailableFcnMode = 'byte';
            self.client.BytesAvailableFcnCount = self.bytesAvailableCnt;
            self.client.BytesAvailableFcn = @self.readDataFcn;
            fopen(self.client);
            
            self.cameraSerial = serial(self.cameraTTLPort, 'BaudRate', self.baudRate);
            fopen(self.cameraSerial);
            
            self.initializeCamera();
        end % CameraAcquisition init
        
        function initializeCamera(self)
            if isempty(self.camera)
                % connection takes time; give some feedback
                fprintf('%s Setting up camera\n', self.LineIndicator);
                % 08/07/2025: ignore dropped frames, keep acquiring
                %(might help prevent camera crashes)
                imaqmex('feature', '-gigeDisablePacketResend', true);
                self.camera = videoinput('gige', 1, 'Mono8');
                fprintf('%s Camera connection established\n', self.LineIndicator);
                self.camera.ROIPosition = self.roiPosition;
                
                src = self.camera.Source;
                src.ExposureTime = self.exposureTime;
                src.AcquisitionFrameRate = self.frameRate;
                src.PacketDelay = 34;
                src.PacketSize = 9000;

                config = triggerinfo(self.camera);
                triggerconfig(self.camera, config(2));
                self.camera.FramesPerTrigger = Inf;
                self.camera.LoggingMode = 'disk';
                self.camera.FramesAcquiredFcnCount = 1;
                self.camera.FramesAcquiredFcn = @self.frameAcquiredTTL;

                preview(self.camera);
            end
        end % initializeCamera
        
        function beginCameraAcquisition(self, pipette, sweep)
            fpath = [self.rootpath '\p' num2str(pipette) '_' num2str(sweep, '%04.f')];
            if isfile([fpath self.ext])
                fpath = [self.rootpath '\p' num2str(pipette) '_' num2str(self.fallbackSweep, '%04.f')];
                self.fallbackSweep = self.fallbackSweep + 1;
            end
            
            logger = VideoWriter([fpath self.ext], self.codec);
            logger.Quality = self.compressionQuality;
            logger.FrameRate = self.frameRate;            
            self.camera.DiskLogger = logger;
                        
            fprintf('%s Acquiring video at %s\n', self.LineIndicator, [fpath self.ext]);
            if ~isempty(self.camera)
                if ~isrunning(self.camera)
                    start(self.camera);
                    trigger(self.camera);
                elseif isrunning(self.camera) && ~islogging(self.camera)
                    trigger(self.camera);
                end
            end
        end % beginCameraAcquisition
        
        function safelyStopCamera(self)
            if ~isempty(self.camera)
                fprintf('%s Safely stopping camera\n', self.LineIndicator);
                if isrunning(self.camera)
%                     fprintf('%s Closing camera\n', self.LineIndicator);
                    stop(self.camera)
%                     wait(self.camera, 1)  % ADDED 11/07/2024 RM
                    fprintf('%s Stopped camera\n', self.LineIndicator);
                    % ADDED 11/07/2024 RM
                    % These lines should help keep the camera from
                    % crashing, but it needs further testing
%                     cnt = 1;
%                     while (self.camera.FramesAcquired ~= self.camera.DiskLoggerFrameCount)
%                         cnt = cnt + 1;
%                         pause(.1)
%                         if cnt > 10
%                             break
%                         end
%                     end
                    fprintf('%s Logged %d/%d frames\n', self.LineIndicator, self.camera.DiskLoggerFrameCount, self.camera.FramesAcquired)
                    % END ADDITION
                    % ADDED 11/08/2024 RM
                    % Closing the logger is creating issues sometimes,
                    % after which script needs to be reboot. Hopefully this
                    % catches the error and allows us to record the next
                    % file.
%                     try
%                         close(self.camera.DiskLogger)
%                         fprintf('%s Closed disklogger\n\n', self.LineIndicator);
%                     catch
%                         pause(.1)
%                         close(self.camera.DiskLogger)
%                         fprintf('%s Error, closed disklogger\n\n', self.LineIndicator);
%                         self.client.BytesAvailableFcnMode = 'byte';
%                         self.client.BytesAvailableFcnCount = self.bytesAvailableCnt;
%                         self.client.BytesAvailableFcn = @self.readDataFcn;
%                     end
                end
            end
        end % safelyStopCamera
        
        function safelyDeleteCamera(self)
            fclose(self.cameraSerial);
            if ~isempty(self.camera)
                fprintf('%s Safely deleting camera object\n', self.LineIndicator);
                if ~isrunning(self.camera)
                    delete(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(self.client);
                    end
                    
                else
                    closepreview(self.camera)
                    stop(self.camera)
                    delete(self.camera)
                    clear(self.camera)
                    
                    if strcmp(self.client.status, 'open')
                        fclose(self.client);
                    end
                end
            end
        end % safelyDeleteCamera
        
        function readDataFcn(self, src, ~)
            arr = fread(src, 3);
            if ~isempty(arr)
                t = arr(1);
                switch t
                    case 1
                        pipette = arr(2);
                        sweep = arr(3);
                        self.beginCameraAcquisition(pipette, sweep);
                    case 2
                        self.safelyStopCamera;
                    case 3
                        self.safelyDeleteCamera;
                end
            end
        end % readDataFcn
        
        function frameAcquiredTTL(self, ~, ~)
            fwrite(self.cameraSerial, 'a');
        end % frameAcquiredTTL

    end % methods
    
end % classdef