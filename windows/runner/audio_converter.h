#ifndef RUNNER_AUDIO_CONVERTER_H_
#define RUNNER_AUDIO_CONVERTER_H_

#include <string>
#include <vector>

#include <windows.h>

HRESULT SelectAudioFiles(HWND owner, std::vector<std::wstring>* paths);
HRESULT SelectMusicFiles(HWND owner, std::vector<std::wstring>* paths);
HRESULT SelectOutputFolder(HWND owner, std::wstring* path);
HRESULT SelectOutputMediaFile(HWND owner, const std::wstring& format,
                              std::wstring* path);

bool ConvertAudioToMp3(const std::wstring& input_path,
                      const std::wstring& output_path, int bitrate_kbps,
                      std::wstring* error_message);
bool ConvertMediaToMp4(const std::wstring& input_path,
                       const std::wstring& output_path,
                       std::wstring* error_message);
std::wstring MakeUniqueMp3Path(const std::wstring& output_directory,
                               const std::wstring& input_path);

#endif  // RUNNER_AUDIO_CONVERTER_H_
