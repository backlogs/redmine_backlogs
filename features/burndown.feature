Feature: Burndown
  As a scrum master
  I want to manage sprints and their stories
  So that they get done according the product owner's requirements

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | Assigned    |         0 |          0 |                    |
        | In Progress |         0 |          0 |                    |
        | Resolved    |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Closed      |         1 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |
      And I have defined the following sprints:
        | name           | sprint_start_date | effective_date  |
        | Sprint 001     | today             | 1.week.from_now |
        | Sprint siegerv | 2011-08-19        | 2011-09-02      |

      And I have defined the following stories in the product backlog:
        | position | subject |
        | 1        | Story 1 |
        | 2        | Story 2 |
        | 3        | Story 3 |
        | 4        | Story 4 |
      And I have defined the following stories in the following sprints:
        | position | subject         | sprint         | points | day |
        | 1        | Story A         | Sprint 001     | 1      |     |
        | 2        | Story B         | Sprint 001     | 2      |     |
        | 3        | Story C         | Sprint 001     | 4      |     |

        | 4        | Siegerv story 1 | Sprint siegerv | 1      |     |

      And I have defined the following tasks:
        | subject      | story            | estimate | status | offset |
        | A.1          | Story A          | 10       | New    | 1h     |
        | B.1          | Story B          | 20       | New    | 1h     |
        | C.1          | Story C          | 40       | New    | 1h     |

        | S.1          | Siegerv story 1  | 10       | New    | 1h     |

  Scenario: Tasks closed AFTER remaining hours is set to 0
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |
       And the sprint burnup should be:
        | day     | points_committed | points_resolved | hours_remaining |
        | start   | 7                | 0               | 70              |
        | 1       | 7                | 0               | 55              |
        | 2       | 7                | 1               | 40              |
        | 3       | 7                | 3               | 25              |
        | 4       | 7                | 3               | 10              |
        | 5       | 7                | 7               | 0               |

  Scenario: Tasks closed BEFORE remaining hours is set to 0
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  |           | Closed      |
        | 2       | A.1  | 0         |             |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  |           | Closed      |
        | 3       | B.1  | 0         |             |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  |           | Closed      |
        | 5       | C.1  | 0         |             |

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 0                 | 0               |

  Scenario: New task and story added during sprint
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |

      And I have defined the following stories in the following sprints:
        | subject | sprint     | points | day |
        | Story D | Sprint 001 | 4      | 3   |

      And I have defined the following tasks:
        | subject      | story     | estimate | status | offset |
        | D.1          | Story D   | 40       | New    | 1h     |

      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 4       | D.1  | 20        | In Progress |
        | 5       | C.1  | 0         |             |
        | 5       | C.1  |           | Closed      |
        | 5       | D.1  | 0         |             |
        | 5       | D.1  |           | Closed      |

      Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 11               | 8                 | 65              |
        | 4       | 11               | 8                 | 30              |
        | 5       | 11               | 0                 | 0               |

  Scenario: Change sprint start date
    Given I am viewing the taskboard for Sprint 001
      And I have changed the sprint start date to tomorrow
      And I have defined the following stories in the following sprints:
        | position | subject | sprint     | points |
        | 4        | Story D | Sprint 001 | 1      |
      And I have changed the sprint start date to today
     Then the sprint burnup should be:
        | day     | points_resolved |
        | start   | 1               |
        | 1       | 1               |

  Scenario: Closed sprint burndown
    Given I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 3       | S.1  | 0         |             |

  Scenario: Saturday and Sunday are included in burndown chart
    Given I have configured backlogs plugin to include Saturday and Sunday in burndown
      And I am viewing the taskboard for Sprint 001
      And I have made the following task mutations:
        | day     | task | remaining | status      |
        | 1       | A.1  | 5         | In Progress |
        | 1       | B.1  | 10        | In Progress |
        | 2       | A.1  | 0         |             |
        | 2       | A.1  |           | Closed      |
        | 2       | C.1  | 30        | In Progress |
        | 3       | B.1  | 0         |             |
        | 3       | B.1  |           | Closed      |
        | 3       | C.1  | 25        |             |
        | 4       | C.1  | 10        |             |
        | 5       | C.1  | 5         |             |
        | 6       | C.1  | 1         |             |
        | 7       | C.1  | 0         |             |
        | 7       | C.1  |           | Closed      |
     Then the sprint burndown should be:
        | day     | points_committed | points_to_resolve | hours_remaining |
        | start   | 7                | 7                 | 70              |
        | 1       | 7                | 7                 | 55              |
        | 2       | 7                | 6                 | 40              |
        | 3       | 7                | 4                 | 25              |
        | 4       | 7                | 4                 | 10              |
        | 5       | 7                | 4                 | 5               |
        | 6       | 7                | 4                 | 1               |
        | 7       | 7                | 0                 | 0               |
      And the sprint burnup should be:
        | day     | points_committed | points_resolved | hours_remaining |
        | start   | 7                | 0               | 70              |
        | 1       | 7                | 0               | 55              |
        | 2       | 7                | 1               | 40              |
        | 3       | 7                | 3               | 25              |
        | 4       | 7                | 3               | 10              |
        | 5       | 7                | 3               | 5               |
        | 6       | 7                | 3               | 1               |
        | 7       | 7                | 7               | 0               |
