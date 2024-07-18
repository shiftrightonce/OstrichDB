package config

import "../../errors"
import "../../logging"
import "core:fmt"
import "core:os"
import "core:strings"


ostConfigHeader := "#This file was generated by the Ostrich Database Engine\n#Do NOT modify this file unless you know what you are doing\n#For more information on the Ostrich Database Engine visit: https://github.com/SchoolyB/Ostrich\n\n\n\n"

configOne := "OST_ENGINE_INIT" //values: true, false...has the engine been initialized
configTwo := "OST_ENGINE_LOGGING" //values: simple, verbose, none???
configThree := "OST_ENGINE_HELP" //values: true, false...helpful hints for users


main :: proc() {
	if (OST_CHECK_IF_CONFIG_FILE_EXISTS() == false) {
		OST_CREATE_CONFIG_FILE()
	}
}


OST_CHECK_IF_CONFIG_FILE_EXISTS :: proc() -> bool {
	configExists: bool
	configPath, e := os.open("../bin")
	defer os.close(configPath)

	foundFiles, readDirSuccess := os.read_dir(configPath, -1)

	if readDirSuccess != 0 {
		error1 := errors.new_err(
			.CANNOT_READ_DIRECTORY,
			errors.get_err_msg(.CANNOT_READ_DIRECTORY),
			#procedure,
		)
		errors.throw_err(error1)
	}
	for file in foundFiles {
		if file.name == "ostrich.config" {
			configExists = true
		}
	}
	return configExists
}

//the config file will contain info like: has the initial user setup been done, engine settings, etc
OST_CREATE_CONFIG_FILE :: proc() -> bool {
	configPath := "../bin/ostrich.config"
	file, createSuccess := os.open(configPath, os.O_CREATE, 0o666)
	os.close(file)
	if createSuccess != 0 {
		error1 := errors.new_err(
			.CANNOT_CREATE_FILE,
			errors.get_err_msg(.CANNOT_CREATE_FILE),
			#procedure,
		)
		errors.throw_err(error1)
		logging.log_utils_error("Error creating config file", "OST_CREATE_CONFIG_FILE")
		return false
	}
	msg := transmute([]u8)ostConfigHeader
	os.open(configPath, os.O_APPEND | os.O_WRONLY, 0o666)
	defer os.close(file)
	writter, writeSuccess := os.write(file, msg)
	if writeSuccess != 0 {
		error2 := errors.new_err(
			.CANNOT_WRITE_TO_FILE,
			errors.get_err_msg(.CANNOT_WRITE_TO_FILE),
			#procedure,
		)
		errors.throw_err(error2)
		logging.log_utils_error("Error writing to config file", "OST_CREATE_CONFIG_FILE")
		return false
	}

	configsFound := OST_FIND_ALL_CONFIGS(configOne, configTwo, configThree)
	if !configsFound {
		OST_APPEND_AND_SET_CONFIG(configOne, "false")
		OST_APPEND_AND_SET_CONFIG(configTwo, "simple")
		OST_APPEND_AND_SET_CONFIG(configThree, "true")
		OST_APPEND_AND_SET_CONFIG("OST_USER_LOGGED_IN", "false")
	}
	return true
}

// Searches the config file for a specific config name that is passed in as a string
// Returns true if found, false if not found
OST_FIND_CONFIG :: proc(c: string) -> bool {
	data, readSuccess := os.read_entire_file("../bin/ostrich.config")
	if readSuccess != false {
		error1 := errors.new_err(
			.CANNOT_READ_FILE,
			errors.get_err_msg(.CANNOT_READ_FILE),
			#procedure,
		)
		errors.throw_err(error1)
		return false
	}
	defer delete(data)

	content := string(data)
	lines := strings.split(content, "\n")
	defer delete(lines)

	for line in lines {
		if strings.contains(line, c) {
			return true
		}
	}
	return false
}

// Ensures that all config names are found in the config file
OST_FIND_ALL_CONFIGS :: proc(configs: ..string) -> bool {
	for config in configs {
		if !OST_FIND_CONFIG(config) {
			return false
		}
	}
	return true
}


OST_APPEND_AND_SET_CONFIG :: proc(c: string, value: string) -> int {
	file, openSuccess := os.open("../bin/ostrich.config", os.O_APPEND | os.O_WRONLY, 0o666)
	if openSuccess != 0 {
		error1 := errors.new_err(
			.CANNOT_OPEN_FILE,
			errors.get_err_msg(.CANNOT_OPEN_FILE),
			#procedure,
		)
		errors.throw_err(error1)
		return 1
	}
	defer os.close(file)
	concat := strings.concatenate([]string{c, " : ", value, "\n"})
	str := transmute([]u8)concat
	writter, writeSuccess := os.write(file, str)

	if writeSuccess != 0 {
		error2 := errors.new_err(
			.CANNOT_WRITE_TO_FILE,
			errors.get_err_msg(.CANNOT_WRITE_TO_FILE),
			#procedure,
		)
		errors.throw_err(error2)
		return 1
	}

	return 0
}


OST_READ_CONFIG_VALUE :: proc(config: string) -> string {
	data, readSuccess := os.read_entire_file("../bin/ostrich.config")
	if !readSuccess {
		error1 := errors.new_err(
			.CANNOT_READ_FILE,
			errors.get_err_msg(.CANNOT_READ_FILE),
			#procedure,
		)
		errors.throw_err(error1)
		return ""
	}

	defer delete(data)

	content := string(data)
	lines := strings.split(content, "\n")
	defer delete(lines)

	for line in lines {
		if strings.contains(line, config) {
			parts := strings.split(line, " : ")
			if len(parts) >= 2 {
				return strings.trim_space(parts[1])
			}
			break // Found the config, but it's malformed
		}
	}

	return "" // Config not found
}


OST_TOGGLE_CONFIG :: proc(config: string) -> bool {
	updated := false
	replaced: bool
	data, readSuccess := os.read_entire_file("../bin/ostrich.config")
	if !readSuccess {
		error1 := errors.new_err(
			.CANNOT_READ_FILE,
			errors.get_err_msg(.CANNOT_READ_FILE),
			#procedure,
		)
		errors.throw_err(error1)
		return false
	}

	defer delete(data)

	content := string(data)
	lines := strings.split(content, "\n")
	defer delete(lines)

	new_lines := make([dynamic]string, 0, len(lines))
	defer delete(new_lines)

	for line in lines {
		new_line := line
		if strings.contains(line, config) {
			if strings.contains(line, "true") {
				new_line, replaced = strings.replace(line, "true", "false", 1)
				updated = true
			} else if strings.contains(line, "false") {
				new_line, replaced = strings.replace(line, "false", "true", 1)
				updated = true
			}
		}
		append(&new_lines, new_line)
	}

	if updated {
		new_content := strings.join(new_lines[:], "\n")
		os.write_entire_file("../bin/ostrich.config", transmute([]byte)new_content)
	}

	return updated
}
