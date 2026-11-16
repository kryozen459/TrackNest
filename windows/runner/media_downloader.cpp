#include "media_downloader.h"

#include <algorithm>
#include <cwctype>
#include <filesystem>
#include <string>
#include <vector>

#include <windows.h>
#include <winhttp.h>
#include <objbase.h>

namespace {

constexpr size_t kMaximumCapturedOutputBytes = 48 * 1024;

std::wstring QuoteArgument(const std::wstring& argument) {
  std::wstring quoted = L"\"";
  size_t backslashes = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'\"') {
      quoted.append(backslashes * 2 + 1, L'\\');
      quoted.push_back(L'\"');
    } else {
      quoted.append(backslashes, L'\\');
      quoted.push_back(character);
    }
    backslashes = 0;
  }
  quoted.append(backslashes * 2, L'\\');
  quoted.push_back(L'\"');
  return quoted;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int required = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                            static_cast<int>(value.size()),
                                            nullptr, 0);
  if (required <= 0) {
    const int fallback = MultiByteToWideChar(
        CP_ACP, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
    if (fallback <= 0) {
      return L"";
    }
    std::wstring output(static_cast<size_t>(fallback), L'\0');
    MultiByteToWideChar(CP_ACP, 0, value.data(),
                        static_cast<int>(value.size()), output.data(), fallback);
    return output;
  }
  std::wstring output(static_cast<size_t>(required), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), required);
  return output;
}

std::wstring RecentOutput(const std::string& output) {
  const size_t start = output.size() > kMaximumCapturedOutputBytes
                           ? output.size() - kMaximumCapturedOutputBytes
                           : 0;
  std::wstring converted = Utf8ToWide(output.substr(start));
  while (!converted.empty() &&
         (converted.back() == L'\r' || converted.back() == L'\n')) {
    converted.pop_back();
  }
  return converted;
}

bool GetExecutableDirectory(std::filesystem::path* directory,
                            std::wstring* error_message) {
  if (directory == nullptr) {
    return false;
  }
  std::vector<wchar_t> module_path(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      nullptr, module_path.data(), static_cast<DWORD>(module_path.size()));
  if (length == 0 || static_cast<size_t>(length) >= module_path.size()) {
    if (error_message != nullptr) {
      *error_message = L"TrackNest could not find its media tools.";
    }
    return false;
  }
  *directory =
      std::filesystem::path(std::wstring(module_path.data(), length)).parent_path();
  return true;
}

bool ValidateUrl(const std::wstring& url, std::wstring* error_message) {
  if (url.empty() || url.size() > 8192) {
    *error_message = L"Enter a valid HTTPS media or playlist link.";
    return false;
  }

  URL_COMPONENTS parts{};
  parts.dwStructSize = sizeof(parts);
  parts.dwSchemeLength = static_cast<DWORD>(-1);
  parts.dwHostNameLength = static_cast<DWORD>(-1);
  parts.dwUserNameLength = static_cast<DWORD>(-1);
  parts.dwPasswordLength = static_cast<DWORD>(-1);
  if (!WinHttpCrackUrl(url.c_str(), 0, 0, &parts) ||
      parts.nScheme != INTERNET_SCHEME_HTTPS ||
      parts.dwHostNameLength == 0) {
    *error_message = L"TrackNest accepts HTTPS links only.";
    return false;
  }
  if (parts.dwUserNameLength != 0 || parts.dwPasswordLength != 0) {
    *error_message = L"Remove any sign-in details embedded in the URL.";
    return false;
  }
  return true;
}

bool RunYtDlp(const std::filesystem::path& tools_directory,
              const std::filesystem::path& working_directory,
              const std::wstring& url, const std::wstring& format,
              int bitrate_kbps, int max_video_height,
              std::wstring* error_message,
              bool* process_started) {
  if (process_started != nullptr) {
    *process_started = false;
  }
  const std::filesystem::path yt_dlp = tools_directory / L"yt-dlp.exe";
  const std::filesystem::path deno = tools_directory / L"deno.exe";
  const std::filesystem::path ffmpeg = tools_directory / L"ffmpeg.exe";
  if (!std::filesystem::is_regular_file(yt_dlp) ||
      !std::filesystem::is_regular_file(deno) ||
      !std::filesystem::is_regular_file(ffmpeg)) {
    *error_message =
        L"The media engine is missing. Rebuild this Windows package with the "
        L"media tools included.";
    return false;
  }

  const std::wstring output_template =
      (working_directory /
       L"%(playlist_index)s - %(title).200B.%(ext)s")
          .wstring();

  std::vector<std::wstring> arguments = {
      yt_dlp.wstring(),
      L"--ignore-config",
      L"--no-cache-dir",
      L"--yes-playlist",
      L"--ignore-errors",
      L"--no-overwrites",
      L"--windows-filenames",
      L"--max-filesize",
      L"2G",
      L"--no-write-info-json",
      L"--no-write-description",
      L"--no-write-thumbnail",
      L"--no-write-subs",
      L"--no-write-auto-subs",
      L"--no-progress",
      L"--js-runtimes",
      L"deno:" + deno.wstring(),
      L"--ffmpeg-location",
      tools_directory.wstring(),
  };

  if (format == L"mp3") {
    arguments.insert(arguments.end(),
                     {L"--format", L"bestaudio/best", L"--extract-audio",
                      L"--audio-format", L"mp3", L"--audio-quality",
                      std::to_wstring(bitrate_kbps) + L"K"});
  } else {
    std::wstring video_format =
        L"bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b";
    if (max_video_height > 0) {
      const std::wstring height_filter =
          L"[height<=" + std::to_wstring(max_video_height) + L"]";
      video_format = L"bv*" + height_filter +
                     L"[ext=mp4]+ba[ext=m4a]/b" + height_filter +
                     L"[ext=mp4]/bv*" + height_filter + L"+ba/b" +
                     height_filter;
    }
    arguments.insert(arguments.end(),
                     {L"--format", video_format,
                      L"--merge-output-format", L"mp4", L"--recode-video",
                      L"mp4"});
  }

  arguments.insert(arguments.end(),
                   {L"--output", output_template, L"--", url});

  std::wstring command_line = QuoteArgument(yt_dlp.wstring());
  for (size_t index = 1; index < arguments.size(); ++index) {
    command_line.push_back(L' ');
    command_line += QuoteArgument(arguments[index]);
  }
  std::vector<wchar_t> mutable_command(command_line.begin(),
                                       command_line.end());
  mutable_command.push_back(L'\0');

  SECURITY_ATTRIBUTES security{};
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;

  HANDLE read_pipe = nullptr;
  HANDLE write_pipe = nullptr;
  if (!CreatePipe(&read_pipe, &write_pipe, &security, 0)) {
    *error_message = L"TrackNest could not start the media engine.";
    return false;
  }
  SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);

  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  startup.hStdOutput = write_pipe;
  startup.hStdError = write_pipe;
  HANDLE null_input = CreateFileW(L"NUL", GENERIC_READ,
                                  FILE_SHARE_READ | FILE_SHARE_WRITE,
                                  &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                                  nullptr);
  if (null_input == INVALID_HANDLE_VALUE) {
    CloseHandle(read_pipe);
    CloseHandle(write_pipe);
    *error_message = L"TrackNest could not prepare the media engine.";
    return false;
  }
  startup.hStdInput = null_input;

  PROCESS_INFORMATION process{};
  const BOOL created = CreateProcessW(
      yt_dlp.c_str(), mutable_command.data(), nullptr, nullptr, TRUE,
      CREATE_NO_WINDOW, nullptr, working_directory.c_str(), &startup, &process);
  CloseHandle(write_pipe);
  CloseHandle(null_input);
  if (!created) {
    CloseHandle(read_pipe);
    *error_message = L"TrackNest could not start the media engine.";
    return false;
  }
  if (process_started != nullptr) {
    *process_started = true;
  }

  CloseHandle(process.hThread);
  std::string captured_output;
  char buffer[8192];
  while (true) {
    DWORD bytes_read = 0;
    if (!ReadFile(read_pipe, buffer, sizeof(buffer), &bytes_read, nullptr) ||
        bytes_read == 0) {
      break;
    }
    captured_output.append(buffer, bytes_read);
    if (captured_output.size() > kMaximumCapturedOutputBytes * 2) {
      captured_output.erase(0, captured_output.size() -
                                   kMaximumCapturedOutputBytes);
    }
  }
  CloseHandle(read_pipe);

  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hProcess);
  if (exit_code == 0) {
    return true;
  }

  std::wstring detail = RecentOutput(captured_output);
  *error_message = L"The site could not provide downloadable media.";
  if (!detail.empty()) {
    *error_message += L"\n\n" + detail;
  }
  return false;
}

bool CompressMp4File(const std::filesystem::path& ffmpeg,
                     const std::filesystem::path& input,
                     std::wstring* error_message) {
  GUID compression_id{};
  if (FAILED(CoCreateGuid(&compression_id))) {
    *error_message = L"Could not prepare video compression.";
    return false;
  }
  wchar_t id_text[40] = {};
  if (StringFromGUID2(compression_id, id_text, ARRAYSIZE(id_text)) == 0) {
    *error_message = L"Could not prepare video compression.";
    return false;
  }
  const std::filesystem::path compressed =
      input.parent_path() /
      (L".tracknest-compressed-" + std::wstring(id_text) + L".mp4");

  std::vector<std::wstring> arguments = {
      ffmpeg.wstring(),
      L"-hide_banner",
      L"-loglevel",
      L"error",
      L"-nostdin",
      L"-y",
      L"-i",
      input.wstring(),
      L"-map",
      L"0:v:0",
      L"-map",
      L"0:a?",
      L"-map_metadata",
      L"0",
      L"-c:v",
      L"libx264",
      L"-preset",
      L"medium",
      L"-crf",
      L"27",
      L"-c:a",
      L"aac",
      L"-b:a",
      L"128k",
      L"-movflags",
      L"+faststart",
      compressed.wstring(),
  };
  std::wstring command_line = QuoteArgument(ffmpeg.wstring());
  for (size_t index = 1; index < arguments.size(); ++index) {
    command_line.push_back(L' ');
    command_line += QuoteArgument(arguments[index]);
  }
  std::vector<wchar_t> mutable_command(command_line.begin(),
                                       command_line.end());
  mutable_command.push_back(L'\0');

  SECURITY_ATTRIBUTES security{};
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;
  HANDLE null_device = CreateFileW(
      L"NUL", GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE, &security, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (null_device == INVALID_HANDLE_VALUE) {
    *error_message = L"Could not prepare video compression.";
    return false;
  }

  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  startup.hStdInput = null_device;
  startup.hStdOutput = null_device;
  startup.hStdError = null_device;
  PROCESS_INFORMATION process{};
  const BOOL created = CreateProcessW(
      ffmpeg.c_str(), mutable_command.data(), nullptr, nullptr, TRUE,
      CREATE_NO_WINDOW, nullptr, input.parent_path().c_str(), &startup,
      &process);
  CloseHandle(null_device);
  if (!created) {
    *error_message = L"Could not start video compression.";
    return false;
  }

  CloseHandle(process.hThread);
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hProcess);
  std::error_code file_error;
  const bool output_exists = std::filesystem::is_regular_file(compressed,
                                                               file_error) &&
                             std::filesystem::file_size(compressed,
                                                        file_error) > 0;
  if (exit_code != 0 || !output_exists ||
      !MoveFileExW(compressed.c_str(), input.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    std::error_code ignored;
    std::filesystem::remove(compressed, ignored);
    *error_message = L"Video compression failed; the original was kept.";
    return false;
  }
  return true;
}

std::filesystem::path UniqueOutputPath(
    const std::filesystem::path& output_directory,
    const std::filesystem::path& source_path) {
  const std::filesystem::path filename = source_path.filename();
  std::filesystem::path candidate = output_directory / filename;
  if (!std::filesystem::exists(candidate)) {
    return candidate;
  }
  const std::wstring stem = filename.stem().wstring();
  const std::wstring extension = filename.extension().wstring();
  for (unsigned int suffix = 2; suffix < 10000; ++suffix) {
    candidate = output_directory /
                (stem + L" (" + std::to_wstring(suffix) + L")" + extension);
    if (!std::filesystem::exists(candidate)) {
      return candidate;
    }
  }
  return {};
}

void RemoveWorkingDirectory(const std::filesystem::path& directory) {
  std::error_code ignored;
  std::filesystem::remove_all(directory, ignored);
}

}  // namespace

bool DownloadAndConvertMediaUrl(const std::wstring& url,
                                const std::wstring& output_directory,
                                const std::wstring& format, int bitrate_kbps,
                                int max_video_height, bool compress_video,
                                std::wstring* error_message) {
  if (error_message == nullptr) {
    return false;
  }
  error_message->clear();
  if (format != L"mp3" && format != L"mp4") {
    *error_message = L"Choose MP3 or MP4 as the output format.";
    return false;
  }
  if (format == L"mp3" &&
      bitrate_kbps != 128 && bitrate_kbps != 192 &&
      bitrate_kbps != 256 && bitrate_kbps != 320) {
    *error_message = L"Choose a supported MP3 bitrate.";
    return false;
  }
  if (max_video_height != 0 && max_video_height != 360 &&
      max_video_height != 480 && max_video_height != 720 &&
      max_video_height != 1080 && max_video_height != 1440 &&
      max_video_height != 2160) {
    *error_message = L"Choose a supported video quality.";
    return false;
  }
  if (format != L"mp4" && compress_video) {
    *error_message = L"Video compression is available for MP4 downloads.";
    return false;
  }
  if (!ValidateUrl(url, error_message)) {
    return false;
  }

  const std::filesystem::path destination(output_directory);
  std::error_code filesystem_error;
  if (!std::filesystem::is_directory(destination, filesystem_error)) {
    *error_message = L"Choose an existing folder for the downloaded media.";
    return false;
  }

  std::filesystem::path executable_directory;
  if (!GetExecutableDirectory(&executable_directory, error_message)) {
    return false;
  }

  GUID job_id{};
  if (FAILED(CoCreateGuid(&job_id))) {
    *error_message = L"TrackNest could not prepare a download folder.";
    return false;
  }
  wchar_t guid_text[40] = {};
  if (StringFromGUID2(job_id, guid_text, ARRAYSIZE(guid_text)) == 0) {
    *error_message = L"TrackNest could not prepare a download folder.";
    return false;
  }

  const std::filesystem::path working_directory =
      destination / (L".tracknest-" + std::wstring(guid_text));
  if (!CreateDirectoryW(working_directory.c_str(), nullptr)) {
    *error_message = L"TrackNest could not prepare a temporary download folder.";
    return false;
  }
  SetFileAttributesW(working_directory.c_str(),
                     FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_TEMPORARY);

  const std::filesystem::path tools_directory =
      executable_directory / L"media-tools";
  const std::filesystem::path ffmpeg = tools_directory / L"ffmpeg.exe";
  bool downloader_started = false;
  const bool downloader_succeeded =
      RunYtDlp(tools_directory, working_directory, url, format, bitrate_kbps,
               max_video_height, error_message, &downloader_started);
  if (!downloader_started) {
    RemoveWorkingDirectory(working_directory);
    return false;
  }
  if (downloader_succeeded) {
    error_message->clear();
  }

  size_t saved_count = 0;
  bool compression_incomplete = false;
  std::error_code enumeration_error;
  for (std::filesystem::directory_iterator iterator(
           working_directory, enumeration_error), end;
       !enumeration_error && iterator != end; iterator.increment(enumeration_error)) {
    const std::filesystem::directory_entry& entry = *iterator;
    if (!entry.is_regular_file()) {
      continue;
    }

    std::wstring extension = entry.path().extension().wstring();
    std::transform(extension.begin(), extension.end(), extension.begin(),
                   [](wchar_t character) {
                     return static_cast<wchar_t>(std::towlower(character));
                   });
    if ((format == L"mp3" && extension != L".mp3") ||
        (format == L"mp4" && extension != L".mp4")) {
      continue;
    }

    if (compress_video) {
      std::wstring compression_error;
      if (!CompressMp4File(ffmpeg, entry.path(), &compression_error)) {
        compression_incomplete = true;
      }
    }

    const std::filesystem::path output =
        UniqueOutputPath(destination, entry.path());
    if (output.empty() ||
        !MoveFileExW(entry.path().c_str(), output.c_str(),
                     MOVEFILE_WRITE_THROUGH)) {
      *error_message =
          L"Some files downloaded, but TrackNest could not move every result "
          L"into the selected folder.";
      RemoveWorkingDirectory(working_directory);
      return saved_count != 0;
    }
    ++saved_count;
  }

  RemoveWorkingDirectory(working_directory);
  if (enumeration_error) {
    *error_message = L"TrackNest could not read the completed downloads.";
    return false;
  }
  if (saved_count == 0) {
    *error_message = L"The link did not produce an MP3 or MP4 file.";
    return false;
  }
  *error_message = L"Saved " + std::to_wstring(saved_count) +
                   (saved_count == 1 ? L" file." : L" files.");
  if (compress_video) {
    *error_message += compression_incomplete
                          ? L" Some videos could not be compressed; their "
                            L"original files were saved."
                          : L" Video compression completed.";
  }
  if (!downloader_succeeded) {
    *error_message +=
        L" Some playlist items could not be downloaded, but the completed "
        L"files were saved.";
  }
  return true;
}
