import 'dart:math';

/// A Dart implementation of the YIN pitch tracking algorithm.
/// Based directly on the mathematical formulas of the YIN paper.
class Yin {
  final int sampleRate;
  final int bufferSize;
  final double threshold;
  
  late List<double> _yinBuffer;

  Yin(this.sampleRate, this.bufferSize, {this.threshold = 0.15}) {
    _yinBuffer = List<double>.filled(bufferSize ~/ 2, 0.0);
  }

  /// Extracts the fundamental frequency from an audio buffer.
  /// Audio buffer should be float values between -1.0 and 1.0.
  /// Returns the frequency in Hz, or -1.0 if pitch was not detected.
  double getPitch(List<double> audioBuffer) {
    int tauEstimate = -1;
    double pitchInHertz = -1.0;

    // Step 2: Difference function
    _difference(audioBuffer);

    // Step 3: Cumulative mean normalized difference function
    _cumulativeMeanNormalizedDifference();

    // Step 4: Absolute threshold
    tauEstimate = _absoluteThreshold();

    if (tauEstimate != -1) {
      // Step 5: Parabolic interpolation
      double interpolatedTau = _parabolicInterpolation(tauEstimate);
      pitchInHertz = sampleRate / interpolatedTau;
    }

    return pitchInHertz;
  }

  /// Step 2: Calculates the squared difference of the signal with a shifted version of itself.
  void _difference(List<double> audioBuffer) {
    int windowSize = _yinBuffer.length;
    for (int tau = 0; tau < windowSize; tau++) {
      double sum = 0.0;
      for (int i = 0; i < windowSize; i++) {
        double delta = audioBuffer[i] - audioBuffer[i + tau];
        sum += delta * delta;
      }
      _yinBuffer[tau] = sum;
    }
  }

  /// Step 3: Normalizes the difference function by the cumulative mean.
  void _cumulativeMeanNormalizedDifference() {
    _yinBuffer[0] = 1.0;
    double runningSum = 0.0;
    
    for (int tau = 1; tau < _yinBuffer.length; tau++) {
      runningSum += _yinBuffer[tau];
      _yinBuffer[tau] = _yinBuffer[tau] * tau / (runningSum == 0.0 ? 1.0 : runningSum);
    }
  }

  /// Step 4: Finds the first tau (lag) that dips below the threshold.
  int _absoluteThreshold() {
    int tau;
    for (tau = 2; tau < _yinBuffer.length; tau++) {
      if (_yinBuffer[tau] < threshold) {
        while (tau + 1 < _yinBuffer.length && _yinBuffer[tau + 1] < _yinBuffer[tau]) {
          tau++;
        }
        return tau;
      }
    }
    
    // If no dip below threshold is found, look for the global minimum
    tau = 2;
    int globalMinTau = tau;
    double minVal = _yinBuffer[tau];
    for (int i = tau + 1; i < _yinBuffer.length; i++) {
      if (_yinBuffer[i] < minVal) {
        minVal = _yinBuffer[i];
        globalMinTau = i;
      }
    }
    // If global minimum is decent, take it (Librosa sometimes relies on this fallback limit)
    if (globalMinTau != -1 && _yinBuffer[globalMinTau] < 0.3) {
      return globalMinTau;
    }
    
    return -1;
  }

  /// Step 5: Interpolates the true minimum between samples for better precision.
  double _parabolicInterpolation(int tauEstimate) {
    int x0 = (tauEstimate < 1) ? tauEstimate : tauEstimate - 1;
    int x2 = (tauEstimate + 1 < _yinBuffer.length) ? tauEstimate + 1 : tauEstimate;
    
    if (x0 == tauEstimate) return (tauEstimate <= _yinBuffer.length) ? tauEstimate.toDouble() : tauEstimate.toDouble();
    if (x2 == tauEstimate) return (tauEstimate <= _yinBuffer.length) ? tauEstimate.toDouble() : tauEstimate.toDouble();
    
    double s0 = _yinBuffer[x0];
    double s1 = _yinBuffer[tauEstimate];
    double s2 = _yinBuffer[x2];
    
    // Position of the parabola's vertex relative to tauEstimate
    double vertexPos = 0.5 * (s2 - s0) / (2.0 * s1 - s2 - s0);
    
    return tauEstimate + vertexPos;
  }
}
