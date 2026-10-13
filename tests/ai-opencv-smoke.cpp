#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/calib3d.hpp>
#include <opencv2/dnn.hpp>
#include <vector>
#include <cmath>

int main()
{
    try {
        cv::Mat image(64, 64, CV_8UC3, cv::Scalar(20, 80, 160)), gray, resized;
        cv::rectangle(image, cv::Rect(16, 16, 24, 24), cv::Scalar(255, 255, 255), 2);
        cv::cvtColor(image, gray, cv::COLOR_BGR2GRAY);
        cv::resize(gray, resized, cv::Size(32, 32));
        if (resized.rows != 32 || resized.cols != 32) return 1;
        for (const char *format : {".png", ".jpg", ".tiff", ".webp"}) {
            std::vector<unsigned char> bytes;
            if (!cv::imencode(format, image, bytes)) return 2;
            cv::Mat decoded = cv::imdecode(bytes, cv::IMREAD_COLOR);
            if (decoded.empty() || decoded.size() != image.size()) return 3;
        }
        std::vector<cv::KeyPoint> points;
        cv::ORB::create()->detect(gray, points);
        std::vector<cv::Point2f> from = {{0,0}, {1,0}, {1,1}, {0,1}};
        std::vector<cv::Point2f> to = {{0,0}, {2,0}, {2,2}, {0,2}};
        cv::Mat transform = cv::findHomography(from, to);
        if (transform.empty() || std::abs(transform.at<double>(0,0)-2) > 1e-6) return 4;
        cv::dnn::Net net;
        cv::dnn::LayerParams params;
        params.set("scale", 2.0f);
        params.set("shift", 1.0f);
        params.set("power", 1.0f);
        int layer = net.addLayer("transform", "Power", params);
        net.connect(0, 0, layer, 0);
        net.setInput(cv::dnn::blobFromImage(cv::Mat::ones(2,2,CV_32F)));
        cv::Mat output = net.forward();
        if (output.total() != 4 || std::abs(output.ptr<float>()[0]-3.0f) > 1e-6) return 5;
        return 0;
    } catch (const cv::Exception &) { return 6; }
}
