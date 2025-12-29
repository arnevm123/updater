package main

import (
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	ff "github.com/peterbourgon/ff/v4"
	"github.com/peterbourgon/ff/v4/ffhelp"
	"github.com/peterbourgon/ff/v4/ffyaml"
)

func Parse(r io.Reader, set func(name, value string) error) error {
	return (&ffyaml.Parser{Delimiter: "_"}).Parse(r, set)
}

// These are the valid log levels, the first one is the default.
var logLevels = []string{
	"info",
	"trace",
	"debug",
	"warn",
	"error",
	"TRACE",
	"INFO",
	"DEBUG",
	"WARN",
	"ERROR",
	"Trace",
	"Info",
	"Debug",
	"Warn",
	"Error",
}

type config struct {
	logLevel string
}

func readProgramVariables(args []string) (cfg config, err error) {
	if len(args) < 1 {
		return config{}, errors.New("not enough arguments provided to the program")
	}

	var configFilePath string
	fs := ff.NewFlagSet("config")

	fs.StringVar(&configFilePath, 'c', "config_file", "", "Path to the config file")
	// Logging
	fs.StringEnumVar(&cfg.logLevel, 0, "log_level", "Application log level", logLevels...)
	// Parse custom config vars
	err = ff.Parse(
		fs,
		args[1:],
		ff.WithEnvVars(),
		ff.WithConfigFileFlag("config_file"),
		ff.WithConfigFileParser(Parse),
		ff.WithConfigAllowMissingFile(),
		ff.WithConfigIgnoreUndefinedFlags(),
	)

	switch { // nolint: revive
	case errors.Is(err, ff.ErrHelp):
		fmt.Fprintf(os.Stderr, "%s\n", ffhelp.Flags(fs))
		return config{}, err
	case err != nil:
		return config{}, fmt.Errorf("ff.Parse: %w", err)
	}

	return cfg, nil
}

func main() {
	config, err := readProgramVariables(os.Args)
	if err != nil {
		// Do a clean exit if help is requested
		if errors.Is(err, ff.ErrHelp) {
			os.Exit(0)
		}
		panic(fmt.Sprintf("Error reading program variables: %v", err))
	}
	setupLogging(config.logLevel)
	slog.Info("Application started")
	slog.Info("Log level set to", slog.String("level", config.logLevel))
}

func setupLogging(levelStr string) {
	baseDir, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	baseDir = filepath.Clean(baseDir)
	handlerOpts := slog.HandlerOptions{
		AddSource: true,
		Level:     getLogLevel(levelStr),
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			if a.Key == slog.SourceKey {
				if src, ok := a.Value.Any().(*slog.Source); ok {
					if rel, err := filepath.Rel(baseDir, src.File); err == nil {
						src.File = rel
					}
				}
			}
			return a
		},
	}

	logger := slog.New(slog.NewTextHandler(os.Stdout, &handlerOpts))

	slog.SetDefault(logger)
}

func getLogLevel(levelStr string) slog.Level {
	switch strings.ToLower(levelStr) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
