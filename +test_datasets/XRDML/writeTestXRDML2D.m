function writeTestXRDML2D(filepath, nOmega, nPixels, options)
%WRITETESTXRDML2D  Write a minimal PANalytical XRDML file with 2D area-detector data.
%
%   Generates a synthetic reciprocal-space map with a Gaussian intensity peak
%   for use in automated tests.  The output is a valid XRDML 2.1 file that
%   importXRDML can parse.  No real instrument is required.
%
%   Syntax
%   ──────
%   writeTestXRDML2D(filepath, nOmega, nPixels)
%   writeTestXRDML2D(filepath, nOmega, nPixels, Name=Value)
%
%   Inputs
%   ──────
%   filepath   string   Output .xrdml file path
%   nOmega     integer  Number of Omega frames (scan axis)
%   nPixels    integer  Number of detector pixels per frame
%
%   Name-Value Options
%   ──────────────────
%   OmegaStart     double  First Omega position (deg)          (default 30.0)
%   OmegaEnd       double  Last  Omega position (deg)          (default 31.0)
%   TwoThetaStart  double  Detector strip start 2Theta (deg)   (default 60.0)
%   TwoThetaEnd    double  Detector strip end   2Theta (deg)   (default 62.0)
%   PeakScale      double  Gaussian peak height (counts)       (default 1000)
%   Background     double  Background level (counts)           (default 50)
%   CountingTime   double  Per-point counting time (s)         (default 0.5)
%   Wavelength     double  Cu Ka1 wavelength (Angstrom)        (default 1.5405980)
%
%   Structure of the output file
%   ────────────────────────────
%   Each of the nOmega <scan> blocks records M=nPixels detector counts at a
%   fixed Omega position (commonPosition) with the 2Theta range the same
%   across all scans.  Stacking the nOmega scans gives an nOmega × nPixels
%   intensity matrix — the pattern importXRDML detects as 2D area-detector data.
%
%   See also IMPORTXRDML, TEST_XRDML_2D

    arguments
        filepath                (1,1) string
        nOmega                  (1,1) double {mustBeInteger, mustBePositive} = 5
        nPixels                 (1,1) double {mustBeInteger, mustBePositive} = 10
        options.OmegaStart      (1,1) double = 30.0
        options.OmegaEnd        (1,1) double = 31.0
        options.TwoThetaStart   (1,1) double = 60.0
        options.TwoThetaEnd     (1,1) double = 62.0
        options.PeakScale       (1,1) double = 1000
        options.Background      (1,1) double = 50
        options.CountingTime    (1,1) double = 0.5
        options.Wavelength      (1,1) double = 1.5405980
    end

    % ── Generate intensity grid ───────────────────────────────────────────────
    omega    = linspace(options.OmegaStart, options.OmegaEnd, nOmega);
    twoTheta = linspace(options.TwoThetaStart, options.TwoThetaEnd, nPixels);

    omCtr  = (options.OmegaStart + options.OmegaEnd) / 2;
    ttCtr  = (options.TwoThetaStart + options.TwoThetaEnd) / 2;
    omSig  = max((options.OmegaEnd - options.OmegaStart) / 3, 1e-9);
    ttSig  = max((options.TwoThetaEnd - options.TwoThetaStart) / 3, 1e-9);

    [TT, OM] = meshgrid(twoTheta, omega);
    I = options.Background + round(options.PeakScale .* ...
        exp(-0.5 .* ((TT - ttCtr) ./ ttSig).^2) .* ...
        exp(-0.5 .* ((OM - omCtr) ./ omSig).^2));

    % ── Write XML ────────────────────────────────────────────────────────────
    fid = fopen(filepath, 'w', 'n', 'UTF-8');
    if fid == -1
        error('writeTestXRDML2D:cannotOpen', 'Cannot open "%s" for writing.', filepath);
    end
    C = onCleanup(@() fclose(fid));

    % Header
    fprintf(fid, '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    fprintf(fid, '<xrdMeasurements xmlns="http://www.xrdml.com/XRDMeasurement/2.1" status="Completed">\n');
    fprintf(fid, '  <xrdMeasurement measurementType="Scan" sampleMode="Reflection">\n');
    fprintf(fid, '    <usedWavelength intended="K-Alpha 1">\n');
    fprintf(fid, '      <kAlpha1 unit="Angstrom">%.7f</kAlpha1>\n', options.Wavelength);
    fprintf(fid, '    </usedWavelength>\n');

    % One <scan> block per Omega position
    for s = 1:nOmega
        cntStr = strjoin(arrayfun(@(v) sprintf('%d', v), I(s,:), 'UniformOutput', false), ' ');
        fprintf(fid, '    <scan appendNumber="%d" mode="Continuous" scanAxis="Omega" status="Completed">\n', s-1);
        fprintf(fid, '      <dataPoints>\n');
        fprintf(fid, '        <positions axis="2Theta" unit="deg">\n');
        fprintf(fid, '          <startPosition>%.6f</startPosition>\n', options.TwoThetaStart);
        fprintf(fid, '          <endPosition>%.6f</endPosition>\n',   options.TwoThetaEnd);
        fprintf(fid, '        </positions>\n');
        fprintf(fid, '        <positions axis="Omega" unit="deg">\n');
        fprintf(fid, '          <commonPosition>%.6f</commonPosition>\n', omega(s));
        fprintf(fid, '        </positions>\n');
        fprintf(fid, '        <commonCountingTime unit="seconds">%.6f</commonCountingTime>\n', options.CountingTime);
        fprintf(fid, '        <counts unit="counts">%s</counts>\n', cntStr);
        fprintf(fid, '      </dataPoints>\n');
        fprintf(fid, '    </scan>\n');
    end

    % Footer
    fprintf(fid, '  </xrdMeasurement>\n');
    fprintf(fid, '</xrdMeasurements>\n');
end
