extends Node

var best_score: int = 0

func update_score(new_score: int):
	if new_score > best_score:
		best_score = new_score

func get_best_score() -> int:
	return best_score
