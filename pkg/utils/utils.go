package utils

// SliceContainsString check if the string slice contains the given string
func SliceContainsString(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}
	return false
}
