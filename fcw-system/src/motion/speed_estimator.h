#pragma once
// ==============================================================================
// Speed Estimator - TIMESTAMP-BASED
// ==============================================================================
// Speed estimation method (selectable via SpeedConfig::useKalmanSpeed):
//
// Method A — Kalman Filter [D, v_closing]  (default, recommended)
//   State:    x = [distance, closing_speed]
//   Dynamics: D_{k+1} = D_k − v·Δt,  v_{k+1} = v_k + ε_a
//   Process noise Q: Singer constant-acceleration model (σ_a from config)
//   Measurement: z = D_bbox (pinhole estimate), H = [1, 0]
//   Warm-start: v_0 estimated from first 2-frame distance difference
//   Benefits: FPS-agnostic (uses real Δt), smooth velocity, models dynamics
//
// Method B — Weighted Linear Regression  (fallback, useKalmanSpeed=false)
//   Weight: w_i = exp(−λ · age_seconds) — recent samples weighted higher
//   Followed by median filter for additional robustness
//
// Ego Speed: Injected externally (KITTI OXTS / CAN Bus / GPS / fixed 50 km/h)
// TTC = Distance / |ClosingSpeed|
// ==============================================================================

#include <unordered_map>
#include <vector>
#include <deque>
#include <opencv2/core.hpp>
#include "distance_estimator.h"
#include "kitti_oxts_reader.h"

namespace fcw {

enum class VehicleState {
    UNKNOWN,
    SAME_DIRECTION,
    STATIONARY,
    ONCOMING
};

// ---------------------------------------------------------------------------
// 2-state Kalman filter: x = [distance (m), closing_speed (m/s)]
// Covariance P stored row-major: [P00, P01, P10, P11]
// ---------------------------------------------------------------------------
struct KalmanSpeedState {
    float D  = 0.0f;                           // Estimated distance (m)
    float v  = 0.0f;                           // Estimated closing speed (m/s, + = approaching)
    float P[4] = {4.0f, 0.0f, 0.0f, 25.0f};  // 2x2 covariance, row-major
    bool  initialized     = false;
    float lastTimestampMs = -1.0f;
};

struct SpeedConfig {
    // Sample buffer (kept for regression fallback & debug)
    int   regressionWindow      = 16;         // Max samples in history deque
    int   medianWindow          = 5;          // Median filter window (regression only)
    float maxSpeed              = 50.0f;      // Hard clamp m/s (180 km/h)

    // Closing speed thresholds
    float minClosingSpeedMs     = 0.2f;       // Dead zone (< 0.72 km/h → not approaching)
    float ttcThreshold          = 6.0f;       // TTC < 6s = approaching window

    // State classification
    float oncomingThreshold     = 15.0f;      // km/h: V_closing > V_ego + this → ONCOMING

    // Sticky Lock (stationary detection hysteresis)
    float stationaryMatchRatio  = 0.25f;
    int   stickyLockThreshold   = 5;
    int   stickyUnlockThreshold = 8;

    // OXTS-based helpers
    float turnYawRateThreshold  = 0.05f;      // rad/s
    float hardBrakeThreshold    = -3.0f;      // m/s²

    // ── Speed estimation method ──────────────────────────────────────────────
    bool  useKalmanSpeed        = true;       // true = Kalman [D,v]; false = weighted regression

    // Kalman parameters (Method A)
    float kalmanSigmaA          = 2.0f;       // Process noise: accel std dev (m/s²)
    float kalmanMeasNoise       = 0.64f;      // Measurement variance R (m²) ~= (0.8m)^2
    float kalmanInitVarD        = 4.0f;       // Initial distance variance P00 (m²)
    float kalmanInitVarV        = 25.0f;      // Initial velocity variance P11 ((m/s)^2)

    // Weighted regression parameters (Method B)
    float regressionLambda      = 0.8f;       // Exp decay rate (1/s); higher = more weight on recent
};

struct SpeedInfo {
    int          trackId             = -1;
    float        closingSpeedMs      = 0.0f;
    float        closingSpeedKmh     = 0.0f;
    float        estimatedTargetKmh  = 0.0f;
    VehicleState vehicleState        = VehicleState::UNKNOWN;
    float        ttcSeconds          = -1.0f;
    float        egoSpeedKmh         = 0.0f;
    bool         isApproaching       = false;
    bool         egoIsBraking        = false;
    bool         valid               = false;
};

class SpeedEstimator {
public:
    SpeedEstimator();
    explicit SpeedEstimator(const SpeedConfig& config);

    void setEgoSpeed(float egoSpeedKmh)    { egoSpeedKmh_ = egoSpeedKmh; }
    void setOxtsData(const OxtsData& data) { currentOxts_ = data; }

    std::unordered_map<int, SpeedInfo> estimate(
        const std::unordered_map<int, DistanceInfo>& distances,
        float timestampMs);

    float     getEgoSpeedKmh() const { return egoSpeedKmh_; }
    SpeedInfo getSpeed(int trackId) const;
    void      setConfig(const SpeedConfig& config);

private:
    SpeedConfig config_;
    float       egoSpeedKmh_     = 0.0f;
    float       lastTimestampMs_ = -1.0f;
    OxtsData    currentOxts_;
    float       prevYaw_         = 0.0f;
    bool        hasPrevYaw_      = false;

    struct TrackSpeedHistory {
        std::deque<float> distanceSamples;      // Smoothed distance history (m)
        std::deque<float> timeSamples;          // Timestamps (ms)
        std::deque<float> closingSpeedHistory;  // For median filter (regression only)
        float currentDistance  = 0.0f;
        int   framesSeen       = 0;
        int   stationaryFrames = 0;
        int   movingFrames     = 0;
        bool  lockedStationary = false;

        KalmanSpeedState kalman;               // 2-state Kalman [D, v_closing]
    };

    std::unordered_map<int, TrackSpeedHistory> trackHistory_;
    std::unordered_map<int, SpeedInfo>         trackSpeeds_;

    // Method A: Kalman filter operations
    void  kalmanPredict(KalmanSpeedState& s, float dt) const;
    float kalmanUpdate(KalmanSpeedState& s, float measuredDist) const;

    // Method B: Weighted linear regression
    float computeRegressionSpeed(const std::deque<float>& distances,
                                 const std::deque<float>& times,
                                 float& outVariance) const;
    float computeMedian(const std::deque<float>& values) const;
};

} // namespace fcw
