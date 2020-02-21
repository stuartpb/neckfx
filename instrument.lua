return {
  watched = function (f,t)
    if t then return function(...)
      print(...)
      return f(t,...)
    end
    else return function(...)
      print(...)
      return f(...)
    end end
  end
}
