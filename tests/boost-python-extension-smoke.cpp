/* SPDX-License-Identifier: MIT */
#include <boost/python.hpp>
#include <stdexcept>

int tdvp_square(int value)
{
 if (value < 0 || value > 1000) throw std::invalid_argument("value outside fixture range");
 return value * value;
}

class TdvpCounter {
 int count_;
public:
 explicit TdvpCounter(int value) : count_(value) {}
 int add(int amount) { count_ += amount; return count_; }
 int value() const { return count_; }
};

BOOST_PYTHON_MODULE(tdvp_boost_probe)
{
 namespace py = boost::python;
 py::def("square", tdvp_square);
 py::class_<TdvpCounter>("Counter", py::init<int>())
  .def("add", &TdvpCounter::add)
  .add_property("value", &TdvpCounter::value);
}
