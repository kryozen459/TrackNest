#ifndef RUNNER_MEDIA_DOWNLOADER_H_
#define RUNNER_MEDIA_DOWNLOADER_H_

#include <string>

bool DownloadAndConvertMediaUrl(const std::wstring& url,
                                const std::wstring& output_directory,
                                const std::wstring& format, int bitrate_kbps,
                                int max_video_height, bool compress_video,
                                std::wstring* error_message);

#endif  // RUNNER_MEDIA_DOWNLOADER_H_
