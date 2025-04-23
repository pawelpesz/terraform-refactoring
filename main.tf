terraform {
  required_version = ">= 1.7.0"
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13"
    }
  }
}

import {
  to = time_static.april_25th_1974
  id = "1974-04-25T08:00:00Z"
}

import {
  to = time_static.june_4th_1989
  id = "1989-06-04T22:00:00Z"
}

import {
  to = time_static.february_11th_1990
  id = "1990-02-11T16:14:00Z"
}
