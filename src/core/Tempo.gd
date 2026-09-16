class_name Tempo
extends RefCounted

## Global terrain/music clock. Course content is authored in bars so movement
## tuning can rescale geometry without invalidating phrase structure.
const BPM: float = 174.0
const BEATS_PER_BAR: int = 4

static func beat_seconds() -> float:
	return 60.0 / BPM

static func beat_meters(avg_speed: float) -> float:
	return avg_speed * beat_seconds()

static func bar_meters(avg_speed: float) -> float:
	return beat_meters(avg_speed) * float(BEATS_PER_BAR)

static func bars_to_meters(bars: float, avg_speed: float) -> float:
	return bars * bar_meters(avg_speed)

static func meters_to_bars(meters: float, avg_speed: float) -> float:
	var bm = bar_meters(avg_speed)
	return meters / bm if bm > 0.0001 else 0.0

static func quantize_bars(bars: float) -> float:
	return quantize_bars_step(bars, 0.5, 0.5)

static func quantize_bars_step(bars: float, step: float, minimum: float = 0.0) -> float:
	var safe_step = maxf(step, 0.001)
	return maxf(minimum, round(bars / safe_step) * safe_step)

static func course_seconds(total_bars: float) -> float:
	return total_bars * float(BEATS_PER_BAR) * beat_seconds()
