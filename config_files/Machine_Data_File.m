% Most Software Machine Data File

%% ScanImage

% Global microscope properties
objectiveResolution = 15;     % Resolution of the objective in microns/degree of scan angle

% Simulated mode
simulated = true;     % Boolean for activating simulated mode. For normal operation, set to 'false'. For operation without NI hardware attached, set to 'true'.

% Optional components
components = {'dabs.thorlabs.ECU1'};     % Cell array of optional components to load. Ex: {'dabs.thorlabs.ECU1' 'dabs.thorlabs.BScope2'}

% Data file location
dataDir = '[MDF]\ConfigData';     % Directory to store persistent configuration and calibration data. '[MDF]' will be replaced by the MDF directory

% Custom Scripts
startUpScript = '';     % Name of script that is executed in workspace 'base' after scanimage initializes
shutDownScript = '';     % Name of script that is executed in workspace 'base' after scanimage exits

%% Shutters
% Shutter(s) used to prevent any beam exposure from reaching specimen during idle periods. Multiple
% shutters can be specified and will be assigned IDs in the order configured below.
shutterNames = {'Main Shutter'};     % Cell array specifying the display name for each shutter eg {'Shutter 1' 'Shutter 2'}
shutterDaqDevices = {'PCIe6374'};     % Cell array specifying the DAQ device or RIO devices for each shutter eg {'PXI1Slot3' 'PXI1Slot4'}
shutterChannelIDs = {'PFI12'};     % Cell array specifying the corresponding channel on the device for each shutter eg {'PFI12'}

shutterOpenLevel = true;     % Logical or 0/1 scalar indicating TTL level (0=LO;1=HI) corresponding to shutter open state for each shutter line. If scalar, value applies to all shutterLineIDs
shutterOpenTime = 0.1;     % Time, in seconds, to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.

%% Beams
beamDaqDevices = {};     % Cell array of strings listing beam DAQs in the system. Each scanner set can be assigned one beam DAQ ex: {'PXI1Slot4'}

% Define the parameters below for each beam DAQ specified above, in the format beamDaqs(N).param = ...
beamDaqs(1).modifiedLineClockIn = '';     % one of {PFI0..15, ''} to which external beam trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).frameClockIn = '';     % one of {PFI0..15, ''} to which external frame clock is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).referenceClockIn = '';     % one of {PFI0..15, ''} to which external reference clock is connected. Leave empty for automatic routing via PXI/RTSI bus
beamDaqs(1).referenceClockRate = 1e+07;     % if referenceClockIn is used, referenceClockRate defines the rate of the reference clock in Hz. Default: 10e6Hz

beamDaqs(1).chanIDs = [];     % Array of integers specifying AO channel IDs, one for each beam modulation channel. Length of array determines number of 'beams'.
beamDaqs(1).displayNames = {};     % Optional string cell array of identifiers for each beam
beamDaqs(1).voltageRanges = 1.5;     % Scalar or array of values specifying voltage range to use for each beam. Scalar applies to each beam.

beamDaqs(1).calInputChanIDs = [];     % Array of integers specifying AI channel IDs, one for each beam modulation channel. Values of nan specify no calibration for particular beam.
beamDaqs(1).calOffsets = [];     % Array of beam calibration offset voltages for each beam calibration channel
beamDaqs(1).calUseRejectedLight = false;     % Scalar or array indicating if rejected light (rather than transmitted light) for each beam's modulation device should be used to calibrate the transmission curve
beamDaqs(1).calOpenShutterIDs = [];     % Array of shutter IDs that must be opened for calibration (ie shutters before light modulation device).

%% Motors
% Motor used for X/Y/Z motion, including stacks.
scaleXYZ = [1 1 1];     % Defines scaling factors for axes.
axisMovesObjective = [false false false];     % Defines if XYZ axes move sample (false) or objective (true)

motors(1).name = '';     % User defined name of the motor controller
motors(1).controllerType = '';     % If supplied, one of {'sutter.mp285', 'sutter.mpc200', 'thorlabs.mcm3000', 'thorlabs.mcm5000', 'scientifica', 'pi.e665', 'pi.e816', 'npoint.lc40x', 'bruker.MAMC'}.
motors(1).dimensions = 'XYZ';     % Assignment of stage dimensions to SI dimensions. Can be any combination of X,Y,Z,- e.g. XY- only uses the first two axes as X and Y axes

%% FastZ
% FastZ hardware used for fast axial motion, supporting fast stacks and/or volume imaging

actuators(1).controllerType = '';     % If supplied, one of {'pi.e665', 'pi.e816', 'npoint.lc40x', 'analog'}.
actuators(1).comPort = [];     % Integer identifying COM port for controller, if using serial communication
actuators(1).customArgs = {};     % Additional arguments to stage controller
actuators(1).daqDeviceName = '';     % String specifying device name used for FastZ control; Specify SLM Scanner name if FastZ device is a SLM
actuators(1).frameClockIn = '';     % One of {PFI0..15, ''} to which external frame trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
actuators(1).cmdOutputChanID = [];     % AO channel number (e.g. 0) used for analog position control
actuators(1).sensorInputChanID = [];     % AI channel number (e.g. 0) used for analog position sensing
actuators(1).commandVoltsPerMicron = 0.1;     % Conversion factor for desired command position in um to output voltage
actuators(1).commandVoltsOffset = 0;     % Offset in volts for desired command position in um to output voltage
actuators(1).sensorVoltsPerMicron = [];     % Conversion factor from sensor signal voltage to actuator position in um. Leave empty for automatic calibration
actuators(1).sensorVoltsOffset = [];     % Sensor signal voltage offset. Leave empty for automatic calibration
actuators(1).maxCommandVolts = [];     % Maximum allowable voltage command
actuators(1).maxCommandPosn = [];     % Maximum allowable position command in microns
actuators(1).minCommandVolts = [];     % Minimum allowable voltage command
actuators(1).minCommandPosn = [];     % Minimum allowable position command in microns
actuators(1).optimizationFcn = '';     % Function for waveform optimization
actuators(1).affectedScanners = {};     % If this actuator only changes the focus for an individual scanner, enter the name

% Field curvature correction params
fieldCurveZ0 = 0;
fieldCurveRx0 = 0;
fieldCurveRy0 = 0;
fieldCurveZ1 = 0;
fieldCurveRx1 = 0;
fieldCurveRy1 = 0;

%% LinScan (ImagingScanner)
simulated = false;     % This scanner is simulated

deviceNameAcq = '';     % string identifying NI DAQ board for PMT channels input
deviceNameGalvo = '';     % string identifying NI DAQ board for controlling X/Y galvo. leave empty if same as deviceNameAcq
deviceNameAux = '';     % string identifying NI DAQ board for outputting clocks. leave empty if unused. Must be a X-series board

fpgaModuleType = 'NI7961';     % String: Type of FlexRIO FPGA module in use when deviceNameAcq is an FPGA. One of {'NI7961' 'NI7975'}
digitizerModuleType = 'NI5732';     % String: Type of digitizer adapter module in use when deviceNameAcq is an FPGA. One of {'NI5732' 'NI5734'}
customSigCondOption = '';     % String: Alternate signal conditioning option when deviceNameAcq is an FPGA
externalSampleClock = false;     % Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module
externalSampleClockRate = [];     % [Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA

% Optional
channelsInvert = false;     % scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels
beamDaqID = [];     % Numeric: ID of the beam DAQ to use with the linear scan system
shutterIDs = [];     % Array of the shutter IDs that must be opened for linear scan system to operate

referenceClockIn = '';     % one of {'',PFI14} to which 10MHz reference clock is connected on Aux board. Leave empty for automatic routing via PXI bus
enableRefClkOutput = false;     % Enables/disables the export of the 10MHz reference clock on PFI14

% Acquisition
channelIDs = [];     % Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)

% Scanner control
XMirrorChannelID = NaN;     % The numeric ID of the Analog Output channel to be used to control the X Galvo.
YMirrorChannelID = NaN;     % The numeric ID of the Analog Output channel to be used to control the y Galvo.

xGalvoAngularRange = 20;     % max range in optical degrees (pk-pk) for x galvo
yGalvoAngularRange = 15;     % max range in optical degrees (pk-pk) for y galvo

voltsPerOpticalDegreeX = 1;     % galvo conversion factor from optical degrees to volts (negative values invert scan direction)
voltsPerOpticalDegreeY = 1;     % galvo conversion factor from optical degrees to volts (negative values invert scan direction)

scanParkAngleX = -8;     % Numeric [deg]: Optical degrees from center position for X galvo to park at when scanning is inactive
scanParkAngleY = -8;     % Numeric [deg]: Optical degrees from center position for Y galvo to park at when scanning is inactive

% Optional: Scanner position feedback
deviceNameGalvoFeedback = '';     % string identifying NI DAQ board that reads the galvo position feedback signals. Leave empty if they are on deviceNameGalvo. Cannot be the same as deviceNameAcq when using for line scanning
XMirrorPosChannelID = [];     % The numeric ID of the Analog Input channel to be used to read the X Galvo position (optional).
XMirrorPosTermCfg = 'Differential';     % AI terminal configuration to be used for reading X-galvo position
YMirrorPosChannelID = [];     % The numeric ID of the Analog Input channel to be used to read the y Galvo position (optional).
YMirrorPosTermCfg = 'Differential';     % AI terminal configuration to be used for reading Y-galvo position

% Optional: Mirror position offset outputs for motion correction
deviceNameOffset = '';     % string identifying NI DAQ board that hosts the offset analog outputs
XMirrorOffsetChannelID = [];     % numeric ID of the Analog Output channel to be used to control the X Galvo offset.
YMirrorOffsetChannelID = [];     % numeric ID of the Analog Output channel to be used to control the y Galvo offset.

XMirrorOffsetMaxVoltage = 1;     % maximum allowed voltage output for the channel specified in XMirrorOffsetChannelID
YMirrorOffsetMaxVoltage = 1;     % maximum allowed voltage output for the channel specified in YMirrorOffsetChannelID

% Advanced/Optional:
stripingEnable = true;     % enables/disables striping display
stripingMaxRate = 10;     % [Hz] determines the maximum display update rate for striping
maxDisplayRate = 30;     % [Hz] limits the maximum display rate (affects frame batching)
internalRefClockSrc = '';     % Reference clock to use internally
internalRefClockRate = [];     % Rate of reference clock to use internally
secondaryFpgaFifo = false;     % specifies if the secondary fpga fifo should be used

% Laser Trigger
LaserTriggerPort = '';     % Port on FlexRIO AM digital breakout (DIO0.[0:3]) or digital IO DAQ (PFI[0:23]) where laser trigger is connected.
LaserTriggerFilterTicks = 0;
LaserTriggerSampleMaskEnable = false;
LaserTriggerSampleWindow = [0 1];
scanheadModel = '';

%% Thorlabs ECU1
scannerName = '';     % Scanner name (from first MDF section) to link to. Must be a resonant scanner
comPort = [];     % Numeric: ID of the ThorECU USB Serial Port (e.g. 12 for COM12);

