class_name CrownZoneContraction
extends Resource

## Seconds from the start of the match or from the first tournament's end, depending on the schedule.
@export_range(0.0, 3600.0, 1.0, "or_greater", "suffix:s") var start_seconds: float = 120.0
## Shorter duration means faster contraction toward the target radius.
@export_range(0.1, 600.0, 0.1, "or_greater", "suffix:s") var duration_seconds: float = 25.0
@export_range(1.0, 10000.0, 1.0, "or_greater", "suffix:px") var target_radius: float = 2900.0
