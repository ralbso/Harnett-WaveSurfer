classdef CameraAcquisition < handle
    properties (Constant=true)
        frameRate = 62
        exposureTime = 15000
        roiPosition = [0 0 592 592]
        compressionQuality = 100
        LineIndicator = '  '
        codec = 'MPEG-4'
        ext = '.mp4'
        user = 'Raul'
        address = '169.254.99.158'
        port = 4545
        bytesAvailableCnt = 8
        fallbackSweep = 101
    end
    
    properties
        rootpath
        client
        camera
    end
    
    methods
        function self = CameraAcquisition(rootpath)
            self.rootpath = rootpath;

            % [~, hostname] = system('hostname');
            % hostname = string(strtrim(hostname));
            % address = resolvehost(hostname, 'address');
            self.client = tcpip(self.address, self.port, 'NetworkRole', 'client');
            self.client.BytesAvailableFcnMode = 'byte';
            self.client.BytesAvailableFcnCount = self.bytesAvailableCnt;
            self.client.BytesAvailableFcn = @self.readDataFcn;
            fopen(self.client);

            self.initializeCamera();
        end % func
        
        function initializeCamera(self)
            if isempty(self.camera)
                % connection takes time; give some feedback
                fprintf('%s Setting up camera\n', self.LineIndicator);
                self.camera = videoinput('gentl', 1, 'Mono8');
                fprintf('%s Camera connection established\n', self.LineIndicator);
                self.camera.ROIPosition = self.roiPosition;
                
                src = self.camera.Source;
                src.ExposureTime = self.exposureTime;
                src.AcquisitionFrameRate = self.frameRate;

                config = triggerinfo(self.camera);
                triggerconfig(self.camera, config(2));
                self.camera.FramesPerTrigger = Inf;
                self.camera.LoggingMode = 'disk';

                preview(self.camera);
            end
        end % func
        
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
                triggerTime = self.camera.InitialTriggerTime;
                fileID = fopen([fpath '.txt'], 'wt');
                fprintf(fileID, datestr(triggerTime, 'HH:MM:SS.FFF'));
                fclose(fileID);
            end
        end % func
        
        function safelyStopCamera(self)
            if ~isempty(self.camera)
                fprintf('%s Safely stopping camera\n', self.LineIndicator);
                if isrunning(self.camera)
                    stop(self.camera)
                end
            end
        end % func
        
        function safelyDeleteCamera(self)
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
                    
                    if strcmp(self.client.status, 'open')
                        fclose(sefl.client);
                    end
                end
            end
        end % func
        
        function readDataFcn(self, src, ~)
            input = fread(src, 24);
            trigger = input(1);
            switch trigger
                case 1
                    pipette = input(2);
                    sweep = input(3);
                    self.beginCameraAcquisition(pipette, sweep);
                case 2
                    self.safelyStopCamera;
                case 3
                    self.safelyDeleteCamera;
            end
        end % func

    end % methods
    
end % classdef